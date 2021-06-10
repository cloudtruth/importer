require_relative 'cloudtruth/importer/logging'
# Need to setup logging before loading any other files
Cloudtruth::Importer::Logging.setup_logging(level: :info, color: false)

require "active_support"

module Cloudtruth
  module Importer
    class Error < StandardError; end

    VERSION = "0.1.0"
  end
end
