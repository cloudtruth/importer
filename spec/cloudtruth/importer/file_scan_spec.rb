require 'rspec'
require 'cloudtruth/importer/file_scan'

module Cloudtruth
  module Importer
    describe FileScan do

      let(:data) { {"foo" => "bar"} }

      def toenv(hash)
        hash.collect{|k, v| "#{k}=#{v}" }.join("\n")
      end

      describe "parse" do

        it "parses as json" do
          expect(described_class.parse(filename: "foo.json", contents: JSON.dump(data))).to eq(data)
          expect(described_class.parse(filename: "stdin", contents: JSON.dump(data), type: "json")).to eq(data)
        end

        it "parses as yaml" do
          expect(described_class.parse(filename: "foo.yaml", contents: YAML.dump(data))).to eq(data)
          expect(described_class.parse(filename: "foo.yml", contents: YAML.dump(data))).to eq(data)
          expect(described_class.parse(filename: "stdin", contents: YAML.dump(data), type: "yaml")).to eq(data)
        end

        it "parses as dotenv" do
          expect(described_class.parse(filename: ".env", contents: toenv(data))).to eq(data)
          expect(described_class.parse(filename: ".env.local", contents: toenv(data))).to eq(data)
          expect(described_class.parse(filename: "stdin", contents: toenv(data), type: "dotenv")).to eq(data)
        end

        it "parses as properties" do
          expect(described_class.parse(filename: "foo.properties", contents: toenv(data))).to eq(data)
          expect(described_class.parse(filename: "stdin", contents: toenv(data), type: "properties")).to eq(data)
        end

        it "parses as xml" do
          expect(described_class.parse(filename: "foo.xml", contents: "<foo>bar</foo>")).to eq(data)
          expect(described_class.parse(filename: "stdin", contents: "<foo>bar</foo>", type: "xml")).to eq(data)
        end

        it "warns for unknown type" do
          Logging.clear
          expect(described_class.parse(filename: "xyz", contents: JSON.dump(data))).to eq(nil)
          expect(Logging.contents).to match(/.*WARN.*unknown mime type.*/)
          Logging.clear
          expect(described_class.parse(filename: "stdin", contents: JSON.dump(data), type: "xyz")).to eq(nil)
          expect(Logging.contents).to match(/.*WARN.*unknown mime type.*/)
        end

        it "raises for parsing failure" do
          expect { described_class.parse(filename: "foo.json", contents: '{') }.to raise_error(FileScan::ParseError, /Failed to parse file/)
        end

        it "loads file if contents not given" do
          expect(File).to receive(:read).with("foo.json").and_return(JSON.dump(data))
          expect(described_class.parse(filename: "foo.json")).to eq(data)
        end

        it "doesn't load file for unknown type" do
          expect(File).to receive(:read).never
          expect(described_class.parse(filename: "foo.json", type: "xyz")).to be_nil
        end

      end

      describe "scan" do

        it "works for a file" do
          within_construct do |c|
            f = c.file('foo.yml', YAML.dump(data))
            expect { |b| described_class.new(path: f.to_s, path_selector: //).scan(&b) }.to yield_with_args(file: f.to_s, data: data, matches_hash: {})
          end
        end

        it "works for a directory" do
          within_construct do |c|
            f1 = c.file('foo.yml', YAML.dump(data))
            f2 = c.file('two/bar.json', JSON.dump(data))
            f3 = c.file('two/three/.env', toenv(data))
            expect { |b| described_class.new(path: c.to_s, path_selector: //).scan(&b) }.
              to yield_successive_args(
                   {file: f1.to_s, data: data, matches_hash: {}},
                   {file: f2.to_s, data: data, matches_hash: {}},
                   {file: f3.to_s, data: data, matches_hash: {}}
                 )
          end
        end

        it "prunes trees with starting dots" do
          within_construct do |c|
            f1 = c.file('foo.yml', YAML.dump(data))
            f2 = c.file('.two/bar.json', JSON.dump(data))
            f3 = c.file('.two/three/.env', toenv(data))

            expect { |b| described_class.new(path: c.to_s, path_selector: //).scan(&b) }.
              to yield_successive_args(
                   {file: f1.to_s, data: data, matches_hash: {}}
                 )
          end
        end

        it "only yields data from files of known types" do
          within_construct do |c|
            f1 = c.file('foo.xyz', YAML.dump(data))
            f2 = c.file('two/bar.abc', JSON.dump(data))
            f3 = c.file('two/three/.312', toenv(data))
            expect { |b| described_class.new(path: c.to_s, path_selector: /two/).scan(&b) }.to_not yield_control
          end
        end

        it "only processes selected files" do
          within_construct do |c|
            f1 = c.file('foo.yml', YAML.dump(data))
            f2 = c.file('two/bar.json', JSON.dump(data))
            f3 = c.file('two/three/.env', toenv(data))
            expect { |b| described_class.new(path: c.to_s, path_selector: /two/).scan(&b) }.
              to yield_successive_args(
                   {file: f2.to_s, data: data, matches_hash: {}},
                   {file: f3.to_s, data: data, matches_hash: {}}
                 )
          end
        end

        it "generates matches from selector" do
          within_construct do |c|
            f1 = c.file('project1/development/foo.yml', YAML.dump(data))
            f2 = c.file('project2/staging/foo.yml', YAML.dump(data))
            selector = %r!(?<project>[^/]+)/(?<environment>[^/]+)/[^/]+$!
            expect { |b| described_class.new(path: c.to_s, path_selector: selector).scan(&b) }.
              to yield_successive_args(
                   {file: f1.to_s, data: data, matches_hash: {environment: "development", project: "project1"}},
                   {file: f2.to_s, data: data, matches_hash: {environment: "staging", project: "project2"}}
                 )
          end
        end


      end

    end
  end
end