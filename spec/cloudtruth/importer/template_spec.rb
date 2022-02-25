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

      describe "CustomLiquidFilters" do

        include Cloudtruth::Importer::Template::CustomLiquidFilters
  
        describe "#dns_safe" do
  
          it "returns if already valid" do
            str = "foo"
            expect(dns_safe(str)).to equal(str)
          end
  
          it "cleans up name" do
            expect(dns_safe("foo_bar")).to eq("foo-bar")
          end
  
          it "forces lower case" do
            expect(dns_safe("Foo_Bar")).to eq("foo-bar")
          end
  
          it "simplifies successive non-chars" do
            expect(dns_safe("foo_&!bar")).to eq("foo-bar")
          end
  
          it "strips leading/trailing non-chars" do
            expect(dns_safe("_foo!bar_")).to eq("foo-bar")
          end
  
        end
  
        describe "#env_safe" do
  
          it "returns if already valid" do
            str = "FOO"
            expect(env_safe(str)).to equal(str)
          end
  
          it "cleans up name" do
            expect(env_safe("foo-bar")).to eq("FOO_BAR")
          end
  
          it "forces upper case" do
            expect(env_safe("Foo")).to eq("FOO")
          end
  
          it "precedes leading digit with underscore" do
            expect(env_safe("9foo")).to eq("_9FOO")
          end
  
          it "simplifies successive non-chars" do
            expect(env_safe("foo-&!bar")).to eq("FOO_BAR")
          end
  
          it "preserves successive underscores" do
            expect(env_safe("__foo__bar__")).to eq("__FOO__BAR__")
          end
  
          it "strips leading/trailing non-chars" do
            expect(env_safe("-foo!bar-")).to eq("FOO_BAR")
          end
  
        end
  
        describe "#key_safe" do
  
          it "returns if already valid" do
            str = "aB1-_."
            expect(key_safe(str)).to equal(str)
          end
  
          it "cleans up name" do
            expect(key_safe("Foo/Bar.Baz-0")).to eq("Foo_Bar.Baz-0")
          end
  
          it "simplifies successive non-chars" do
            expect(key_safe("foo/&!bar")).to eq("foo_bar")
          end
  
        end
  
        describe "#indent" do
  
          it "indents by count spaces for each line" do
            expect(indent("foo\nbar", 3)).to eq("   foo\n   bar")
          end
  
        end
  
        describe "#nindent" do
  
          it "indents by count spaces for each line with a leading newline" do
            expect(nindent("foo\nbar", 3)).to eq("   \n   foo\n   bar")
          end
  
        end
  
        describe "#stringify" do
  
          it "produces a yaml string" do
            expect(stringify("foo")).to eq('"foo"')
            expect(stringify(%q(foo'"bar))).to eq(%q("foo'\"bar"))
          end
  
        end
  
        describe "#to_yaml" do
  
          it "produces a yaml string" do
            expect(to_yaml([1, 2])).to eq("---\n- 1\n- 2\n")
            # also check how liquid handles named parameters
            expect(described_class.new("{{ var | to_yaml }}").render(var: [1, 2])).to eq("---\n- 1\n- 2\n")
          end
  
          it "produces header free yaml" do
            expect(to_yaml([1, 2], "no_header" => false)).to eq("---\n- 1\n- 2\n")
            expect(to_yaml([1, 2], "no_header" => true)).to eq("- 1\n- 2\n")
            expect(to_yaml({"foo" => "bar"}, "no_header" => true)).to eq("foo: bar\n")
            # also verify that liquid handles named parameters
            expect(described_class.new("{{ var | to_yaml: no_header: true}}").render(var: [1, 2])).to eq("- 1\n- 2\n")
            expect(described_class.new("{{ var | to_yaml: no_header: false}}").render(var: [1, 2])).to eq("---\n- 1\n- 2\n")
          end
  
        end
  
        describe "#to_json" do
  
          it "produces a json string" do
            expect(to_json({"foo" => "bar"})).to eq('{"foo":"bar"}')
          end
  
        end
  
        describe "#sha256" do
  
          it "does a sha256 digest" do
            expect(sha256("foo")).to eq(Digest::SHA256.hexdigest("foo"))
          end
  
        end
  
        describe "#encode64" do
  
          it "does a base64 encode" do
            expect(encode64("foo")).to eq(Base64.strict_encode64("foo"))
          end
  
        end
  
        describe "#decode64" do
  
          it "does a base64 decode" do
            expect(decode64(Base64.strict_encode64("foo"))).to eq("foo")
          end
  
        end
  
        describe "#inflate" do
  
          it "works with empty" do
            expect(inflate({})).to eq({})
          end
  
          it "adds structure using delimiter" do
            data = {
              "topval" => 0,
              "top.mid.bottom1" => 1,
              "top.mid.bottom2" => 2,
              "top.midval" => 3,
              "other.someval" => 4
            }
            result = {
              "topval" => 0,
              "top" => {
                "mid" => {
                  "bottom1" => 1,
                  "bottom2" => 2
                },
                "midval" => 3
              },
              "other" => {
                "someval" => 4
              }
            }
            expect(inflate(data)).to eq(result)
          end
  
          it "can use other delimiter" do
            data = {
              "top/mid/bottom1" => 1
            }
            result = {
              "top" => {
                "mid" => {
                  "bottom1" => 1
                }
              }
            }
            expect(inflate(data, "/")).to eq(result)
          end
  
          it "can use regex delimiter" do
            data = {
              "top//mid///bottom1" => 1
            }
            result = {
              "top" => {
                "mid" => {
                  "bottom1" => 1
                }
              }
            }
            expect(inflate(data, "/+")).to eq(result)
          end
  
        end
  
        describe "#deflate" do
  
          it "works with empty" do
            expect(inflate({})).to eq({})
          end
  
          it "adds structure using delimiter" do
            result = {
              "topstr" => "hi",
              "topnum" => 3,
              "toptrue" => true,
              "topfalse" => false,
              "toplist" => "[1,2,3]",
              "top.mid.bottom1" => 1,
              "top.mid.bottom2" => 2,
              "top.midval" => 3,
              "other.someval" => 4
            }
            data = {
              "topstr" => "hi",
              "topnum" => 3,
              "toptrue" => true,
              "topfalse" => false,
              "toplist" => [1, 2, 3],
              "top" => {
                "mid" => {
                  "bottom1" => 1,
                  "bottom2" => 2
                },
                "midval" => 3
              },
              "other" => {
                "someval" => 4
              }
            }
            expect(deflate(data)).to eq(result)
          end
  
          it "can use other delimiter" do
            result = {
              "top/mid/bottom1" => 1
            }
            data = {
              "top" => {
                "mid" => {
                  "bottom1" => 1
                }
              }
            }
            expect(deflate(data, "/")).to eq(result)
          end
  
        end
  
        describe "#typify" do
  
          it "works with empty" do
            expect(typify(nil)).to eq(nil)
            expect(typify("")).to eq("")
            expect(typify(true)).to eq(true)
            expect(typify(3)).to eq(3)
            expect(typify(3.4)).to eq(3.4)
            expect(typify({})).to eq({})
            expect(typify([])).to eq([])
          end
  
          it "converts string to type" do
            expect(typify("hello")).to eq("hello")
            expect(typify("true")).to eq(true)
            expect(typify("false")).to eq(false)
            expect(typify("3")).to eq(3)
            expect(typify("3.4")).to eq(3.4)
          end
  
          it "recursively typifys structure" do
            data = {
              "top" => {
                "mid" => [
                  {
                    "bottom" => "1"
                  },
                  {
                    "bottom" => "1.2"
                  },
                  {
                    "bottom" => "true"
                  },
                  {
                    "bottom" => "false"
                  },
                  {
                    "bottom" => "hello"
                  }
                ]
              }
            }
            result = {
              "top" => {
                "mid" => [
                  {
                    "bottom" => 1
                  },
                  {
                    "bottom" => 1.2
                  },
                  {
                    "bottom" => true
                  },
                  {
                    "bottom" => false
                  },
                  {
                    "bottom" => "hello"
                  }
                ]
              }
            }
            expect(typify(data)).to eq(result)
          end

          it "converts embedded json" do
            expect(typify('[1, 2, 3]')).to eq([1, 2, 3])
            expect(typify('{"foo": "bar"}')).to eq({"foo" => "bar"})
          end

          it "converts embedded yaml" do
            expect(typify('[1, 2, 3]', "yaml")).to eq([1, 2, 3])
            expect(typify('{foo: bar}', "yaml")).to eq({"foo" => "bar"})
          end

          it "recurses conversion of embedded" do
            expect(typify('[1, 2, "3"]')).to eq([1, 2, 3])
            expect(typify('{"foo": "true"}')).to eq({"foo" => true})
          end

          it "fails for invalid parser on embedded yaml" do
            expect { typify("[1, 2, 3]", "yoyo") }.to raise_error(RuntimeError, /Invalid typify parser/)
          end

        end
  
        describe "#merge" do

          it "merges two maps" do
            m1 = {"x" => "y", "a" => "z"}
            m2 = {"a" => "b", "y" => "z"}
            expect(merge(m1, m2)).to eq(m1.merge(m2))
            expect(described_class.new("{{ m1 | merge: m2 | to_json }}").render(m1: m1, m2: m2)).to eq(m1.merge(m2).to_json)
          end
  
  
          it "handles nil rhs" do
            m1 = {"x" => "y", "a" => "z"}
            m2 = nil
            expect(merge(m1, m2)).to eq(m1)
            expect(described_class.new("{{ m1 | merge: m2 | to_json }}").render(m1: m1, m2: m2)).to eq(m1.to_json)
          end
  
        end
  
        describe "#re_replace" do
  
          it "performs gsub" do
            expect(re_replace("foobar", "o+", "X")).to eq("fXbar")
            expect(described_class.new('{{ "foobar" | re_replace: "o+", "X" }}').render()).to eq("fXbar")
          end
  
          it "handles flags" do
            expect(re_replace("fOObar", "o+", "X")).to eq("fOObar")
            expect(re_replace("fOObar", "o+", "X", "i")).to eq("fXbar")
            expect(re_replace("FOO\nOO", "f.*", "X", "i")).to eq("X\nOO")
            expect(re_replace("FOO\nOO", "f.*", "X", "mi")).to eq("X")
          end
  
          it "handles backrefs" do
            expect(re_replace("foobar", "(o+)b", "XX\\1YY")).to eq("fXXooYYar")
          end
  
        end
  
        describe "#re_contains" do
  
          it "performs match" do
            expect(re_contains("foobar", "o+")).to eq(true)
            expect(re_contains("foobar", "x+")).to eq(false)
            expect(described_class.new('{{ "foobar" | re_contains: "o+" }}').render()).to eq("true")
          end
  
          it "handles flags" do
            expect(re_contains("fOObar", "o+")).to eq(false)
            expect(re_contains("fOObar", "o+", "i")).to eq(true)
            expect(re_contains("FOO\nOO", "f.{5}", "i")).to eq(false)
            expect(re_contains("FOO\nOO", "f.{5}", "mi")).to eq(true)
          end
  
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
