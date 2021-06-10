require 'rspec'
require 'cloudtruth/importer/parameter'

module Cloudtruth
  module Importer
    describe Parameter do

      let(:all_attrs) { Hash[[:environment, :project, :key, :value, :secret, :fqn, :jmes].collect {|a| [a, a]}] }
      let(:min_attrs) { Hash[[:environment, :project, :key, :value].collect {|a| [a, a]}] }

      describe "validations" do

        it "succeeds with valid attrs" do
          Logging.clear
          described_class.new(min_attrs)
          expect(Logging.contents).to be_blank
        end

        it "requires environment" do
          expect { described_class.new(min_attrs.reject {|k,v| k == :environment}) }.to raise_error(ArgumentError, "environment is required")
          expect { described_class.new(min_attrs.merge(environment: "")) }.to raise_error(ArgumentError, "environment is required")
        end

        it "requires project" do
          expect { described_class.new(min_attrs.reject {|k,v| k == :project}) }.to raise_error(ArgumentError, "project is required")
          expect { described_class.new(min_attrs.merge(project: "")) }.to raise_error(ArgumentError, "project is required")
        end

        it "requires key" do
          expect { described_class.new(min_attrs.reject {|k,v| k == :key}) }.to raise_error(ArgumentError, "key is required")
          expect { described_class.new(min_attrs.merge(key: "")) }.to raise_error(ArgumentError, "key is required")
        end

        it "requires value" do
          expect { described_class.new(min_attrs.reject {|k,v| k == :value}) }.to raise_error(ArgumentError, /value.*is required/)
          expect { described_class.new(min_attrs.merge(value: nil)) }.to raise_error(ArgumentError, /value.*is required/)
          expect { described_class.new(min_attrs.merge(value: "")) }.to_not raise_error
        end

        it "requires fqn and jmes in place of value" do
          attrs = min_attrs.reject {|k,v| k == :value}
          expect { described_class.new(attrs) }.to raise_error(ArgumentError, /fqn.*is required/)
          attrs = attrs.merge(fqn: :fqn)
          expect { described_class.new(attrs) }.to raise_error(ArgumentError, /jmes.*is required/)
          attrs = attrs.merge(jmes: :jmes)
          expect { described_class.new(attrs) }.to_not raise_error

          expect { described_class.new(min_attrs.reject {|k,v| k == :value}.merge(fqn: :fqn, jmes: "")) }.to raise_error(ArgumentError, /jmes.*is required/)
          expect { described_class.new(min_attrs.reject {|k,v| k == :value}.merge(fqn: "", jmes: :jmes)) }.to raise_error(ArgumentError, /jmes.*is required/)
        end

        it "warns for both fqn+jmes/value" do
          Logging.clear
          described_class.new(all_attrs)
          expect(Logging.contents).to match(/.*WARN.*Value is set, will ignore fqn.*/)
        end

      end

    end
  end
end