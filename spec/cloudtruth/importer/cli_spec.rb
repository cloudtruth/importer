require 'rspec'
require 'cloudtruth/importer/cli'

module Cloudtruth
  module Importer
    describe CLI do

      let(:cli) { described_class.new("") }
      let(:ctcli) { CtCLI.new(dry_run: true) }
      let(:param) { Parameter.new(environment: "default", project: "default", key: "foo", value: "bar") }

      def all_usage(clazz, path=[])
        Enumerator.new do |y|
          obj = clazz.new("")
          path << clazz.name.split(":").last if path.empty?
          cmd_path = path.join(" -> ")
          y << {name: cmd_path, usage: obj.help}

          clazz.recognised_subcommands.each do |sc|
            sc_clazz = sc.subcommand_class
            sc_name = sc.names.first
            all_usage(sc_clazz, path + [sc_name]).each {|sy| y << sy}
          end
        end
      end

      describe "--help" do

        it "produces help text under standard width" do
          all_usage(described_class).each do |m|
            expect(m[:usage]).to be_line_width_for_cli(m[:name])
          end
        end

      end

      describe "version" do

        it "uses flag to produce version text" do
          expect { cli.run(%w[--version]) }.to raise_error(SystemExit)
          expect(Logging.contents).to include(VERSION)
        end

      end

      describe "--debug" do

        it "defaults to info log level" do
          expect(Logging).to receive(:setup_logging).with(hash_including(level: :info))
          expect { cli.run(%w[--version]) }.to raise_error(SystemExit)
        end

        it "sets log level to debug" do
          expect(Logging).to receive(:setup_logging).with(hash_including(level: :debug))
          expect { cli.run(%w[--version --debug]) }.to raise_error(SystemExit)
        end

      end

      describe "--quiet" do

        it "defaults to info log level" do
          expect(Logging).to receive(:setup_logging).with(hash_including(level: :info))
          expect { cli.run(%w[--version]) }.to raise_error(SystemExit)
        end

        it "sets log level to warn" do
          expect(Logging).to receive(:setup_logging).with(hash_including(level: :error))
          expect { cli.run(%w[--version --quiet]) }.to raise_error(SystemExit)
        end

      end

      describe "--no-color" do

        it "defaults to color" do
          expect(Logging).to receive(:setup_logging).with(hash_including(color: true))
          expect { cli.run(%w[--version]) }.to raise_error(SystemExit)
        end

        it "outputs plain text" do
          expect(Logging).to receive(:setup_logging).with(hash_including(color: false))
          expect { cli.run(%w[--version --no-color]) }.to raise_error(SystemExit)
        end

      end

      describe "--stdin" do

        it "requires recognized format" do
          expect { cli.parse(%w[--stdin json]) }.to_not raise_error
          expect { cli.parse(%w[--stdin yaml]) }.to_not raise_error
          expect { cli.parse(%w[--stdin dotenv]) }.to_not raise_error
          expect { cli.parse(%w[--stdin properties]) }.to_not raise_error
          expect { cli.parse(%w[--stdin xml]) }.to_not raise_error
          expect { cli.parse(%w[--stdin foo]) }.to raise_error(Clamp::UsageError, /--stdin.*Invalid type/)
        end

      end

      describe "paths" do

        it "requires stdin or path" do
          expect { cli.run(%w[]) }.to raise_error(Clamp::UsageError, "A path must be given or stdin enabled")
        end

      end

      describe "get_transformer" do

        it "uses default template" do
          cli.parse(%w[path])
          transformer = cli.get_transformer
          expect(transformer.source).to eq(CLI::DEFAULT_TRANSFORM)
        end

        it "can give template through option" do
          cli.parse(%w[--transform foo path])
          transformer = cli.get_transformer
          expect(transformer.source).to eq("foo")
        end

        it "can give template via file" do
          cli.parse(%w[--transform-file foo path])
          expect(File).to receive(:read).with("foo").and_return("bar")
          transformer = cli.get_transformer
          expect(transformer.source).to eq("bar")
        end

      end

      describe "parse_paths" do

        it "reads from stdin" do
          cli.parse(%w[--stdin json])
          expect($stdin).to receive(:read).and_return("[{}]")
          expect { |b| cli.parse_paths(&b) }.to yield_with_args(file: "stdin", data: [{}], matches_hash: {})
        end

        it "reads from paths" do
          cli.parse(%w[--path-selector . foo.yaml bar.json])
          within_construct do |c|
            f1 = c.file('foo.yaml', YAML.dump([1]))
            f2 = c.file('bar.json', JSON.dump([2]))
            expect(FileScan).to receive(:new).with(path: "foo.yaml", path_selector: /./).and_call_original
            expect(FileScan).to receive(:new).with(path: "bar.json", path_selector: /./).and_call_original
            expect { |b| cli.parse_paths(&b) }.
              to yield_successive_args(
                   {file: "foo.yaml", data: [1], matches_hash: {}},
                   {file: "bar.json", data: [2], matches_hash: {}}
                 )
          end
        end

      end

      describe "read_data" do

        it "generates a list of params by applying template to structured data" do
          data = {"foo" => "bar"}
          cli.parse(%w[--stdin json])
          expect($stdin).to receive(:read).and_return(JSON.dump(data))
          expect(cli.read_data(cli.get_transformer)).to eq([param])
        end

      end

      describe "ensure_projects" do

        it "creates projects" do
          expect(ctcli).to receive(:ensure_project).with(param.project, "")
          cli.ensure_projects(ctcli, [param])
        end

        it "creates project heirarchy" do
          params = [
            Parameter.new(project: "proj2", project_parent: "proj1", environment: "default", key: "foo", value: "bar"),
            Parameter.new(project: "proj3", project_parent: "proj2", environment: "default", key: "foo", value: "bar"),
            Parameter.new(project: "proj1", environment: "default", key: "foo", value: "bar"),
          ]
          expect(ctcli).to receive(:ensure_project).with("proj1", "").ordered
          expect(ctcli).to receive(:ensure_project).with("proj2", "proj1").ordered
          expect(ctcli).to receive(:ensure_project).with("proj3", "proj2").ordered
          cli.ensure_projects(ctcli, params)
        end

        it "creates projects for unassociated parents" do
          params = [
            Parameter.new(project: "proj1", project_parent: "", environment: "default", key: "foo", value: "bar"),
            Parameter.new(project: "proj3", project_parent: "other", environment: "default", key: "foo", value: "bar"),
          ]
          expect(ctcli).to receive(:ensure_project).with("proj1", "").ordered
          expect(ctcli).to receive(:ensure_project).with("other", "").ordered
          expect(ctcli).to receive(:ensure_project).with("proj3", "other").ordered
          cli.ensure_projects(ctcli, params)
        end
      end

      describe "ensure_environments" do

        it "creates environments" do
          param.environment = "foo"
          expect(ctcli).to receive(:ensure_environment).with(param.environment, "default")
          cli.ensure_environments(ctcli, [param])
        end

        it "doesn't create default environment" do
          param.environment = "default"
          expect(ctcli).to_not receive(:ensure_environment)
          cli.ensure_environments(ctcli, [param])
        end

        it "creates environment heirarchy" do
          params = [
            Parameter.new(environment: "env2", environment_parent: "env1", project: "default", key: "foo", value: "bar"),
            Parameter.new(environment: "env3", environment_parent: "env2", project: "default", key: "foo", value: "bar"),
            Parameter.new(environment: "env1", environment_parent: "default", project: "default", key: "foo", value: "bar"),
          ]
          expect(ctcli).to receive(:ensure_environment).with("env1", "default").ordered
          expect(ctcli).to receive(:ensure_environment).with("env2", "env1").ordered
          expect(ctcli).to receive(:ensure_environment).with("env3", "env2").ordered
          cli.ensure_environments(ctcli, params)
        end

        it "creates environments for unassociated parents" do
          params = [
            Parameter.new(environment: "env1", environment_parent: "default", project: "default", key: "foo", value: "bar"),
            Parameter.new(environment: "env3", environment_parent: "other", project: "default", key: "foo", value: "bar"),
          ]
          expect(ctcli).to receive(:ensure_environment).with("env1", "default").ordered
          expect(ctcli).to receive(:ensure_environment).with("other", "default").ordered
          expect(ctcli).to receive(:ensure_environment).with("env3", "other").ordered
          cli.ensure_environments(ctcli, params)
        end

      end

      describe "apply_params" do

        it "uses cli to set params" do
          cli.parse(%w[path])
          expect(CtCLI).to receive(:new).with(dry_run: false).and_return(ctcli)
          expect(ctcli).to receive(:get_param_names).and_return([])
          expect(ctcli).to receive(:set_params).with([param])
          expect(ctcli).to_not receive(:ensure_environment)
          expect(ctcli).to_not receive(:ensure_project)
          cli.apply_params([param])
        end

        it "skips existing params" do
          cli.parse(%w[path])
          param2 = param.dup; param.key = "key2"
          expect(CtCLI).to receive(:new).with(dry_run: false).and_return(ctcli)
          expect(ctcli).to receive(:get_param_names).and_return([param.key])
          expect(ctcli).to receive(:set_params).with([param2])
          cli.apply_params([param, param2])
        end

        it "forces set of existing params with --override" do
          cli.parse(%w[--override path])
          expect(CtCLI).to receive(:new).with(dry_run: false).and_return(ctcli)
          expect(ctcli).to_not receive(:get_param_names)
          expect(ctcli).to receive(:set_params).with([param])
          cli.apply_params([param])
        end

        it "ensures environments with --create-environments" do
          cli.parse(%w[--create-environments path])
          expect(CtCLI).to receive(:new).with(dry_run: false).and_return(ctcli)
          allow(ctcli).to receive(:get_param_names).and_return([])
          expect(cli).to receive(:ensure_environments).with(ctcli, [param])
          expect(cli).to_not receive(:ensure_projects)
          cli.apply_params([param])
        end

        it "ensures projects with --create-environments" do
          cli.parse(%w[--create-projects path])
          expect(CtCLI).to receive(:new).with(dry_run: false).and_return(ctcli)
          allow(ctcli).to receive(:get_param_names).and_return([])
          expect(cli).to receive(:ensure_projects).with(ctcli, [param])
          expect(cli).to_not receive(:ensure_environments)
          cli.apply_params([param])
        end

      end


      describe "execute" do

        it "does it" do
          template = double(Template)
          params = []

          expect(cli).to receive(:get_transformer).and_return(template)
          expect(cli).to receive(:read_data).with(template).and_return(params)
          expect(cli).to receive(:apply_params).with(params)

          cli.run(%w[path])
        end

        it "prints expected exceptions" do
          expect(cli).to receive(:get_transformer).and_raise(Cloudtruth::Importer::Error.new("mybad"))
          expect { cli.run(%w[path]) }.to raise_error(SystemExit)
          expect(Logging.contents).to match(/ERROR.*mybad/)
        end

      end

    end
  end
end
