require 'open3'
require 'set'
require 'cloudtruth/importer/parameter'

module Cloudtruth
  module Importer
    class CtCLI
      include GemLogger::LoggerSupport

      def initialize(dry_run: false)
        @dry_run = dry_run
      end

      def set_params(params)
        params.each do |param|
          set_param(param)
        end
      end

      def set_param(param)
        cmd = %W[cloudtruth --env #{param.environment} --project #{param.project} param set]
        cmd << "--secret" << "true" if param.secret
        if ! param.value.nil?
          cmd.concat(%W[--value #{param.value}])
        else
          cmd.concat(%W[--fqn #{param.fqn}])
          cmd.concat(%W[--jmes #{param.jmes}]) if param.jmes.present?
        end
        cmd << param.key

        if @dry_run
          logger.info cmd.inspect
        else
          execute(*cmd)
        end
      end

      def get_environments
        cmd = %W[cloudtruth environments list]
        data = execute(*cmd, capture_stdout: true)
        Set.new(data.split)
      end

      def ensure_environment(environment, parent=nil)
        cmd = %W[cloudtruth environments set]
        cmd.concat(%W[--parent #{parent}]) if parent.present?
        cmd << environment
        if @dry_run
          logger.info cmd.inspect
        else
          execute(*cmd)
        end
      end

      def get_projects
        cmd = %W[cloudtruth projects list]
        data = execute(*cmd, capture_stdout: true)
        Set.new(data.split)
      end

      def ensure_project(project, parent=nil)
        cmd = %W[cloudtruth projects set]
        cmd.concat(%W[--parent #{parent}]) if parent.present?
        cmd << project
        if @dry_run
          logger.info cmd.inspect
        else
          execute(*cmd)
        end
      end

      def get_param_names(project)
        cmd = %W[cloudtruth --project #{project} param ls]
        data = ""
        begin
          data = execute(*cmd, capture_stdout: true)
        rescue
          if @dry_run
            logger.warn "Ignoring failure in param lookup failure due to dry run"
            data = ""
          else
            raise
          end
        end
        if data =~ /No parameters found/
          data = ""
        end
        Set.new(data.split)
      end

      def execute(*cmd, capture_stdout: false)
        output = ""
        logger.debug{"Running Cloudtruth CLI: #{cmd.inspect} "}

        status = nil
        if capture_stdout
          result = Open3.capture2(*cmd)
          output = result[0]
          status = result[1]
        else
          system(*cmd)
          status = $?
        end

        raise "Cloudtruth CLI exited with non-zero exit code: #{status.exitstatus}" unless status.success?

        return output
      end

    end
  end
end
