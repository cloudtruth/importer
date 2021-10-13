require 'find'
require 'mimemagic'
require 'json'
require 'yaml'
require 'dotenv'
require 'java-properties'
require 'ox'

module Cloudtruth
  module Importer
    class FileScan
      include GemLogger::LoggerSupport

      class ParseError < Cloudtruth::Importer::Error; end

      def self.parse(filename:, contents: nil, type: nil)
        type ||= MimeMagic.by_path(filename).try(&:type)
        type ||= (File.basename(filename) =~ /^[\.\-]env/ ? "dotenv" : nil )
        type ||= (File.extname(filename) == ".properties" ? "properties" : nil )

        begin

          case type
            when /json/i
              logger.debug{"Attempting to parse #{filename} as json"}
              contents ||= File.read(filename)
              result = JSON.parse(contents)
            when /ya?ml/i
              logger.debug{"Attempting to parse #{filename} as yaml"}
              contents ||= File.read(filename)
              result = YAML.load(contents)
            when /dotenv/i
              logger.debug{"Attempting to parse #{filename} as dotenv"}
              contents ||= File.read(filename)
              result = Dotenv::Parser.call(contents)
            when /properties/i
              logger.debug{"Attempting to parse #{filename} as java properties"}
              contents ||= File.read(filename)
              result = JavaProperties.parse(contents)
            when /xml/i
              logger.debug{"Attempting to parse #{filename} as xml"}
              contents ||= File.read(filename)
              result = Ox.load(contents, mode: :hash)
            else
              logger.warn "Skipping file '#{filename}' due to unknown mime type '#{type}'"
              return nil
          end

          result = result.deep_stringify_keys if result.is_a?(Hash)
          return result

        rescue => e
          raise ParseError, "Failed to parse file '#{filename}' as type '#{type}': #{e.class}, #{e.message}"
        end

      end

      def initialize(path:, path_selector:)
        @path = path
        # The pattern for matching files, can use a regexp group to determine project or environment from the match
        @path_selector = path_selector
      end

      def scan
        Find.find(@path) do |f|
          if File.directory?(f) && File.basename(f).start_with?('.')
            logger.debug { "Ignoring path: #{f}" }
            Find.prune
          end

          next if File.directory?(f)

          match = f.match(@path_selector)
          if match.nil?
            logger.debug { "Skipping non-matching file: #{f}" }
            next
          end

          matches_hash = match.named_captures.symbolize_keys
          logger.debug { "Processing matching file '#{f}' with match data: #{matches_hash.inspect}" }

          data = self.class.parse(filename: f)
          next if data.nil?

          yield file: f, data: data, matches_hash: matches_hash

        end
        logger.debug{"File scan complete"}
      end

    end
  end
end
