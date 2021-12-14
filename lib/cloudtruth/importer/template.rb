require 'liquid'

module Cloudtruth
  module Importer
    class Template

      include GemLogger::LoggerSupport

      class Error < Cloudtruth::Importer::Error
      end

      module CustomLiquidFilters

        DNS_VALIDATION_RE = /^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$/
        ENV_VALIDATION_RE = /^[A-Z_][A-Z0-9_]*$/
        KEY_VALIDATION_RE = /^[\w\.\-]*$/
  
        def dns_safe(str)
          return str if str =~ DNS_VALIDATION_RE
          result = str.to_s.downcase.gsub(/[^-.a-z0-9)]+/, '-')
          result = result.gsub(/(^[^a-z0-9]+)|([^a-z0-9]+$)/, '')
          result
        end
  
        def env_safe(str)
          return str if str =~ ENV_VALIDATION_RE
          result = str.upcase
          result = result.gsub(/(^\W+)|(\W+$)/, '')
          result = result.gsub(/\W+/, '_')
          result = result.sub(/^\d/, '_\&')
          result
        end
  
        def key_safe(str)
          return str if str =~ KEY_VALIDATION_RE
          str.gsub(/[^\w\.\-]+/, '_')
        end
  
        def indent(str, count)
          result = ""
          str.lines.each do |l|
            result << (" " * count) << l
          end
          result
        end
  
        def nindent(str, count)
          indent("\n" + str, count)
        end
  
        def stringify(str)
          str.to_s.to_json
        end
  
        def to_yaml(str, options = {})
          options = {} unless options.is_a?(Hash)
          result = str.to_yaml
          result = result[4..-1] if options['no_header']
          result
        end
  
        def to_json(str)
          str.to_json
        end
  
        def sha256(data)
          Digest::SHA256.hexdigest(data)
        end
  
        def encode64(str)
          Base64.strict_encode64(str)
        end
  
        def decode64(str)
          Base64.strict_decode64(str)
        end
  
        def deflate(hash, delimiter='.')
          result = {}
  
          hash.each do |k, v|
            case v
              when String, Numeric, TrueClass, FalseClass
                result[k] = v
              when Array
                result[k] = JSON.generate(v)
              when Hash
                m = deflate(v, delimiter)
                m.each do |mk, mv|
                  result["#{k}#{delimiter}#{mk}"] = mv
                end
              else
                result[k] = v.to_s
            end
          end
  
          return result
        end
  
        def inflate(map, delimiter='\.')
          result = {}
          map.each do |k, v|
            path = k.split(/#{delimiter}/)
            scoped = result
            path.each_with_index do |p, i|
              if i == (path.size - 1)
                scoped[p] = v
              else
                scoped[p] ||= {}
                scoped = scoped[p]
              end
            end
          end
          result
        end
  
        def typify(data)
          case data
            when Hash
              Hash[data.collect {|k,v| [k, typify(v)] }]
            when Array
              data.collect {|v| typify(v) }
            when /^[0-9]+$/
              data.to_i
            when /^[0-9\.]+$/
              data.to_f
            when /true|false/
              data == "true"
            else
              data
          end
        end
  
      end
  
      Liquid::Template.register_filter(CustomLiquidFilters)
  
      attr_reader :source

      def initialize(template_source)
        logger.debug {"Parsing template: #{template_source}"}
        @source = template_source
        begin
          @liquid = Liquid::Template.parse(@source, error_mode: :strict)
        rescue Liquid::Error => e
          raise Error.new(e.message)
        end
      end

      def render(**kwargs)
        begin
          logger.debug { "Evaluating template '#{@source}' with context: #{kwargs.inspect}" }
          result = @liquid.render!(kwargs.stringify_keys, strict_variables: true, strict_filters: true)
          result
        rescue Liquid::Error => e
          indent = "  "
          msg = "Template failed to render:\n"
          @source.lines.each {|l| msg << (indent * 2) << l }
          msg << indent << "with error message:\n" << (indent * 2) << "#{e.message}"
          if e.is_a?(Liquid::UndefinedVariable)
            msg << "\n" << indent << "and variable context:\n"
            msg << (indent * 2) << kwargs.inspect
          end
          raise Error, msg
        end
      end

      def to_s
        @source
      end

    end
  end
end
