module Cloudtruth
  module Importer
    Parameter = Struct.new(:environment, :environment_parent, :project, :project_parent, :key, :value, :secret, :fqn, :jmes, keyword_init: true) do
      include GemLogger::LoggerSupport

      def initialize(*args, **kwargs)
        super

        raise ArgumentError.new("environment is required") if environment.blank?
        raise ArgumentError.new("project is required") if project.blank?
        raise ArgumentError.new("key is required") if key.blank?

        # value can be empty string, but fqn/jmes can't
        if value.nil?
          if fqn.blank?
            raise ArgumentError.new("A parameter value or fqn+jmes is required")
          end
        else
          if fqn.present? || jmes.present?
            logger.warn("Value is set, will ignore fqn+jmes: #{self}")
          end
        end
      end
    end
  end
end
