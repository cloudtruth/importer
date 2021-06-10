require 'clamp'
require_relative 'parameter'
require_relative 'template'
require_relative 'file_scan'
require_relative 'ctcli'

module Cloudtruth
  module Importer
    class CLI < Clamp::Command

      include GemLogger::LoggerSupport

      banner <<~'EOF'
        Scans the given directories and files (or stdin) to extract
        parameters and add them to cloudtruth.  Each data file is parsed and
        passed into the `--transform` template in order to generate a list of
        parameter definitions that are created within cloudtruth.  By default,
        only new parameters are added to cloudtruth unless you pass the
        `--override` flag.
      EOF

      option "--environment",
             'ENV', "The cloudtruth environment to use if you don't want to determine one during transformation",
             default: "default"

      option "--project",
             'PROJECT', "The cloudtruth project to use if you don't want to determine one during transformation",
             default: "default"

      option "--path-selector",
             'REGEX', "The regex to select paths, providing named matches to template transform.  e.g. '(?<environment>[^/]+)/(?<project>[^/]+).yaml'",
             default: "" do |arg|
        Regexp.new(arg)
      end

      DEFAULT_TRANSFORM = <<~EOF
        {% for entry in data %}
        - environment: "{{ environment }}"
          project: "{{ project }}"
          key: "{{ entry[0] }}"
          value: "{{ entry[1] }}"
        {% endfor %}
      EOF

      option "--transform",
             'TMPL',
              <<~EOF
               A transformation template (https://shopify.github.io/liquid/) to
               convert input data to a list of parameters.  This should
               generate a yaml list of parameters, each a hash of
               {environment:, project:, key:, value;, secret:, fqn:, jmes:}.
               The template context will contain the variables environment,
               project, data, filename, and any named captures from matching
               against the filename.
               Default:
               #{DEFAULT_TRANSFORM}
              EOF

      option "--transform-file",
             'FILE', 'A file containing the transformation template, takes precedence over `--transform`'

      option ["-s", "--stdin"],
             'TYPE', 'Read data from stdin as the given type json, yaml or dotenv' do |a|
        raise ArgumentError("Invalid type") unless a =~ /json|ya?ml|dotenv/
        a
      end

      option "--create-projects",
             :flag, "Create projects if they don't exist",
             default: false

      option "--create-environments",
             :flag, "Create environments if they don't exist",
             default: false

      option ["-o", "--override"],
             :flag, "Force override of parameters in cloudtruth if they already exist",
             default: false

      option ["-n", "--dry-run"],
             :flag, "Perform a dry run",
             default: false

      option ["-q", "--quiet"],
             :flag, "Suppress output",
             default: false

      option ["-d", "--debug"],
             :flag, "Debug output",
             default: false

      option ["-c", "--[no-]color"],
             :flag, "colorize output (or not)  (default: $stdout.tty?)",
             default: true

      option ["-v", "--version"],
             :flag, "show version",
             default: false

      parameter "PATH ...",
                'The directories and/or files to scan for data, use `--path-selector` for additional restrictions.  Use `--stdin <type>` to read data from stdin.',
                required: false

      # hook into clamp lifecycle to force logging setup even when we are calling
      # a subcommand
      def parse(arguments)
        super

        level = :info
        level = :debug if debug?
        level = :error if quiet?
        Cloudtruth::Importer::Logging.setup_logging(level: level, color: color?)
      end

      def parse_paths
        if stdin.present?
          logger.info "Reading parameter data from stdin"
          contents = $stdin.read
          data = FileScan.parse(filename: "stdin", contents: contents, type: stdin)
          if data
            yield file: "stdin", data: data, matches_hash: {}
          end
        end

        path_list.each do |path|
          FileScan.new(path: path, path_selector: path_selector).scan do |file:, data:, matches_hash:|
            yield file: file, data: data, matches_hash: matches_hash
          end
        end
      end

      def get_transformer
        transform_tmpl = File.read(transform_file) if transform_file.present?
        transform_tmpl ||= transform
        transform_tmpl ||= DEFAULT_TRANSFORM
        transform = Template.new(transform_tmpl)
        transform
      end

      def read_data(transformer)
        params = []
        parse_paths do |file:, data:, matches_hash:|
          tmpl_vars = {environment: environment, project: project, filename: file}.merge(matches_hash).merge(data: data)
          result = transformer.render(**tmpl_vars)
          logger.debug{"Transformed data: #{result}"}
          param_data = YAML.load(result)
          params.concat(param_data.collect { |item| Parameter.new(**item) })
        end
        params
      end

      def apply_params(params)
        cli = CtCLI.new(dry_run: dry_run?)
        param_groups = params.group_by {|p| {environment: p[:environment], project: p[:project]} }
        param_groups.each do |group, params|
          cli.ensure_environment(group[:environment]) if create_environments?
          cli.ensure_project(group[:project]) if create_projects?
          unless override?
            existing = cli.get_param_names(group[:project])
            logger.debug {"Existing parameters for #{group}: #{existing.inspect}"}
            params = params.reject {|p| existing.include?(p.key) }
            logger.info "No new parameters for #{group}" if params.size == 0
          end
          cli.set_params(params)
        end
      end

      def execute
        if version?
          logger.info "Cloudtruth Importer Version #{VERSION}"
          exit(0)
        end

        if stdin.blank? && path_list.empty?
          signal_usage_error("A path must be given or stdin enabled")
        end

        begin
          transformer = get_transformer
          params = read_data(transformer)
          apply_params(params)
        rescue Cloudtruth::Importer::Error => e
          logger.log_exception(e, "", level: :debug)
          logger.error(e.message)
          exit(1)
        end
      end

    end
  end

  # Hack to make clamp usage less of a pain to get long lines to fit within a
  # standard terminal width
  class Clamp::Help::Builder

    def word_wrap(text, line_width: 79)
      text.split("\n").collect do |line|
        line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip.split("\n") : line
      end.flatten
    end

    def string
      indent_size = 4
      indent = " " * indent_size
      StringIO.new.tap do |out|
        lines.each do |line|
          case line
            when Array
              if line[0].length > 0
                out << indent
                out.puts(line[0])
              end

              formatted_line = line[1].gsub(/\((default|required)/, "\n\\0")
              word_wrap(formatted_line, line_width: (79 - indent_size * 2)).each do |l|
                out << (indent * 2)
                out.puts(l)
              end
            else
              out.puts(line)
          end
        end
      end.string
    end

  end
end
