require 'rspec'
require 'cloudtruth/importer/template'

module Cloudtruth
  module Importer
    describe Template do

      describe "#to_s" do

        it "shows the template source" do
          expect(Template.new("foo").to_s).to eq("foo")
        end

      end

      describe "regexp match" do

        it "sets matchdata to nil for missing matches" do
          regex = /^(?<head>[^_]*)(_(?<tail>.*))?$/
          expect("foo_bar".match(regex).named_captures.symbolize_keys).to eq(head: "foo", tail: "bar")
          expect("foobar".match(regex).named_captures.symbolize_keys).to eq(head: "foobar", tail: nil)
        end

      end

      describe "#render" do

        it "works with plain strings" do
          expect(described_class.new(nil).render).to eq("")
          expect(described_class.new("").render).to eq("")
          expect(described_class.new("foo").render).to eq("foo")
        end

        it "substitutes from kwargs" do
          expect(described_class.new("hello {{foo}}").render("foo" => "bar")).to eq("hello bar")
          expect(described_class.new("hello {{foo}}").render(foo: "bar")).to eq("hello bar")
        end

        it "handles nil value in kwargs" do
          expect(described_class.new("hello {{foo}}").render(foo: nil)).to eq("hello ")
        end

        it "fails fast" do
          expect { described_class.new("{{foo") }.to raise_error(Template::Error)
          expect { described_class.new("{{foo}}").render }.to raise_error(Template::Error)
          expect { described_class.new("{{foo | nofilter}}").render(foo: "bar") }.to raise_error(Template::Error)
        end

      end

    end
  end
end
