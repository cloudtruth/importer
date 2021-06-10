require 'liquid'

module Cloudtruth
  module Importer
    class Template

      include GemLogger::LoggerSupport

      class Error < Cloudtruth::Importer::Error
      end

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
