require 'rspec'
require 'cloudtruth/importer/ctcli'

module Cloudtruth
  module Importer
    describe CtCLI do

      let(:param) { Parameter.new(environment: "env1", project: "proj1", key: "key1", value: "value1") }
      let(:cli) { described_class.new }

      describe "execute" do

        it "runs a successful non-capturing command" do
          cmd = %w[/bin/sh -c true]
          expect(cli).to receive(:system).with(*cmd).and_call_original
          cli.execute(*cmd, capture_stdout: false)
        end

        it "runs a failing non-capturing command" do
          cmd = %w[/bin/sh -c false]
          expect(cli).to receive(:system).with(*cmd).and_call_original
          expect{ cli.execute(*cmd, capture_stdout: false) }.to raise_error(RuntimeError, /Cloudtruth CLI exited with non-zero exit code/)
        end

        it "runs a successful capturing command" do
          cmd = %w[/bin/sh -c echo\ hi]
          expect(Open3).to receive(:capture2).with(*cmd).and_call_original
          expect(cli.execute(*cmd, capture_stdout: true)).to eq("hi\n")
        end

        it "runs a failing capturing command" do
          cmd = %w[/bin/sh -c false]
          expect(Open3).to receive(:capture2).with(*cmd).and_call_original
          expect{ cli.execute(*cmd, capture_stdout: true) }.to raise_error(RuntimeError, /Cloudtruth CLI exited with non-zero exit code/)
        end

      end

      describe "dry_run" do

        it "performs no writes for dry run" do
          cli = described_class.new(dry_run: true)
          expect(cli).to_not receive(:execute)
          cli.set_param(param)
          cli.ensure_environment(param.environment)
          cli.ensure_project(param.project)
        end

      end

      describe "get_environments" do

        it "gets the environments" do
          expect(cli).to receive(:execute).with(*%w[cloudtruth environments list], capture_stdout: true).and_return("env1\nenv2")
          expect(cli.get_environments).to eq(Set.new(%w[env1 env2]))
        end

      end

      describe "ensure_environment" do

        it "ensures the environments" do
          expect(cli).to receive(:execute).with(*%w[cloudtruth environments set env1])
          cli.ensure_environment("env1")
        end

        it "ensures parented environment" do
          expect(cli).to receive(:execute).with(*%w[cloudtruth environments set --parent parentenv env1])
          cli.ensure_environment("env1", "parentenv")
        end

      end

      describe "get_projects" do

        it "gets the projects" do
          expect(cli).to receive(:execute).with(*%w[cloudtruth projects list], capture_stdout: true).and_return("proj1\nproj2")
          expect(cli.get_projects).to eq(Set.new(%w[proj1 proj2]))
        end

      end

      describe "ensure_project" do

        it "ensures the project" do
          expect(cli).to receive(:execute).with(*%w[cloudtruth projects set proj1])
          cli.ensure_project("proj1")
        end

        it "ensures parented project" do
          expect(cli).to receive(:execute).with(*%w[cloudtruth projects set --parent parentproj proj1])
          cli.ensure_project("proj1", "parentproj")
        end


      end

      describe "get_param_names" do

        it "gets the param names" do
          expect(cli).to receive(:execute).with(*%w[cloudtruth --project proj1 param ls], capture_stdout: true).and_return("key1\nkey2")
          expect(cli.get_param_names("proj1")).to eq(Set.new(%w[key1 key2]))
        end

        it "handles no params" do
          expect(cli).to receive(:execute).with(*%w[cloudtruth --project proj1 param ls], capture_stdout: true).and_return("No parameters found in project proj1")
          expect(cli.get_param_names("proj1")).to eq(Set.new([]))
        end

        it "ignores failure for dry run" do
          cli = described_class.new(dry_run: false)
          expect(cli).to receive(:execute).with(*%w[cloudtruth --project proj1 param ls], capture_stdout: true).and_raise(RuntimeError, "bad")
          expect{cli.get_param_names("proj1")}.to raise_error(RuntimeError, "bad")

          cli = described_class.new(dry_run: true)
          expect(cli).to receive(:execute).with(*%w[cloudtruth --project proj1 param ls], capture_stdout: true).and_raise(RuntimeError, "bad")
          expect(cli.get_param_names("proj1")).to eq(Set.new())
        end

      end

      describe "set_param" do

        it "sets a basic param" do
          param = Parameter.new(environment: "env1", project: "proj1", key: "key1", value: "value1")
          expect(cli).to receive(:execute).with(*%w[cloudtruth --env env1 --project proj1 param set --value value1 key1])
          cli.set_param(param)
        end

        it "sets a secret param" do
          param = Parameter.new(environment: "env1", project: "proj1", key: "key1", value: "value1", secret: true)
          expect(cli).to receive(:execute).with(*%w[cloudtruth --env env1 --project proj1 param set --secret true --value value1 key1])
          cli.set_param(param)
        end

        it "sets a fqn/jmes param" do
          param = Parameter.new(environment: "env1", project: "proj1", key: "key1", fqn: "fqn1", jmes: "jmes1")
          expect(cli).to receive(:execute).with(*%w[cloudtruth --env env1 --project proj1 param set --fqn fqn1 --jmes jmes1 key1])
          cli.set_param(param)
        end

        it "sets a only a fqn param" do
          param = Parameter.new(environment: "env1", project: "proj1", key: "key1", fqn: "fqn1")
          expect(cli).to receive(:execute).with(*%w[cloudtruth --env env1 --project proj1 param set --fqn fqn1 key1])
          cli.set_param(param)
        end

        it "uses value over fqn/jmes" do
          param = Parameter.new(environment: "env1", project: "proj1", key: "key1", value: "value1", fqn: "fqn1", jmes: "jmes1")
          expect(cli).to receive(:execute).with(*%w[cloudtruth --env env1 --project proj1 param set --value value1 key1])
          cli.set_param(param)
        end

      end

      describe "set_params" do

        it "sets a list of params" do
          param1 = param.dup
          param2 = param.dup
          expect(cli).to receive(:set_param).with(param1)
          expect(cli).to receive(:set_param).with(param2)
          cli.set_params([param1, param2])
        end

      end

      describe "import_params" do

        it "sets a list of params" do
          expect(cli).to_not receive(:set_param)
          expect(cli).to receive(:execute).with(*%w[cloudtruth import parameters --environment env1 proj1], /importer.*\.yml/)
          cli.import_params(project: param.project, environment: param.environment, parameters: [param])
        end
  
        it "indicates secrets" do
          params = [
            Parameter.new(environment: "env1", project: "proj1", key: "key1", value: "value1", secret: false),
            Parameter.new(environment: "env1", project: "proj1", key: "key2", value: "value2", secret: true),
          ]
          expect(cli).to receive(:execute).with(*%w[cloudtruth import parameters --environment env1 proj1], /importer.*\.yml/, "--secret", "key2")
          cli.import_params(project: params.first.project, environment: params.first.environment, parameters: params)
        end
                
        it "sets a list of params" do
          expect(cli).to_not receive(:set_param)
          expect(cli).to receive(:execute) do |*args, **kwargs|
            expect(File.read(args.last)).to eq({param.key => param.value}.to_yaml)
          end

          cli.import_params(project: param.project, environment: param.environment, parameters: [param])
        end

        it "use set_params for fqn" do
          params = [
            Parameter.new(environment: "env1", project: "proj1", key: "key1", value: "value1"),
            Parameter.new(environment: "env1", project: "proj1", key: "key2", fqn: "value2"),
          ]
          expect(cli).to receive(:execute).with(*%w[cloudtruth import parameters --environment env1 proj1], /importer.*\.yml/)
          expect(cli).to receive(:set_params).with([params.last])
          cli.import_params(project: params.first.project, environment: params.first.environment, parameters: params)
        end
                
        it "uses --preview for dry run" do
          cli = described_class.new(dry_run: true)
          expect(cli).to receive(:execute).with(*%w[cloudtruth import parameters --environment env1 proj1], /importer.*\.yml/, '--preview')
          cli.import_params(project: param.project, environment: param.environment, parameters: [param])
        end
        
        it "uses --no-inherit when set" do
          expect(cli).to receive(:execute).with(*%w[cloudtruth import parameters --environment env1 proj1], /importer.*\.yml/, '--no-inherit')
          cli.import_params(project: param.project, environment: param.environment, parameters: [param], no_inherit: true)
        end
        
      end

    end

 
  end
end
