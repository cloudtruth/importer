require "bundler/setup"
ENV['CLOUDTRUTH_API_KEY'] ||= 'fake_api_key'
require "cloudtruth-importer"

require "open3"

require 'simplecov'
SimpleCov.start do
  add_filter 'spec'
end

if ENV['CI'] && ENV['CODECOV_TOKEN']
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  # config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    Cloudtruth::Importer::Logging.testing = true
    Cloudtruth::Importer::Logging.setup_logging(level: :debug, color: false)
    Cloudtruth::Importer::Logging.clear
  end

  config.after(:each) do |example|
    if example.exception
      puts
      puts "Debug log for failing spec: #{example.full_description}"
      puts Cloudtruth::Importer::Logging.contents
      puts
    end
  end

end

require "test_construct/rspec_integration"

RSpec::Matchers.define :be_line_width_for_cli do |name|
  match do |actual|
    @actual = []
    @expected = []
    actual.lines.each {|l| @actual << l if l.chomp.size > 80}
    !(actual.nil? || actual.empty?) && @actual.size == 0
  end

  diffable

  failure_message do |actual|
    maybe_name = name.nil? ? "" : "[subcommand=#{name}] "
    if @actual.size == 0
      "#{maybe_name}No lines in output"
    else
      "#{maybe_name}Some lines are longer than standard terminal width"
    end
  end
end

require 'stringio'

module IoTestHelpers
  def simulate_stdin(*inputs, &block)
    io = StringIO.new
    inputs.flatten.each { |str| io.puts(str) }
    io.rewind

    actual_stdin, $stdin = $stdin, io
    yield
  ensure
    $stdin = actual_stdin
  end

  def sysrun(*args, output_on_fail: true, allow_fail: false, stdin_data: nil)
    args = args.compact
    output, status = Open3.capture2e(*args, stdin_data: stdin_data)
    puts output if output_on_fail && status.exitstatus != 0
    if ! allow_fail
      expect(status.exitstatus).to eq(0), "#{args.join(' ')} failed: #{output}"
    end
    return output
  end

end

include IoTestHelpers
