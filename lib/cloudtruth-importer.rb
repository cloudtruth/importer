require_relative 'cloudtruth/importer/logging'
# Need to setup logging before loading any other files
Cloudtruth::Importer::Logging.setup_logging(level: :info, color: false)

require "active_support"

module Cloudtruth
  module Importer
    VERSION = YAML.load(File.read(File.expand_path('../.app.yml', __dir__)),
                        filename: File.expand_path('../.app.yml', __dir__),
                        symbolize_names: true)[:version]

    class Error < StandardError; end
  end
end
