# encoding: utf-8

%w{
  sippy_cup
  fakefs/spec_helpers
  tempfile
}.each { |f| require f }

module SippyCup
  module SpecHelpers
    def capture(stream)
      stream = stream.to_s
      captured_stream = Tempfile.new(stream)
      stream_io = eval("$#{stream}")
      origin_stream = stream_io.dup
      stream_io.reopen(captured_stream)

      yield

      stream_io.rewind
      return captured_stream.read
    ensure
      captured_stream.close
      captured_stream.unlink
      stream_io.reopen(origin_stream)
    end

    def silence_stream(stream)
      old_stream = stream.dup
      stream.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
      stream.sync = true
      yield
    ensure
      stream.reopen(old_stream)
      old_stream.close
    end
  end
end

RSpec.configure do |config|
  config.include SippyCup::SpecHelpers
  config.mock_framework = :rspec
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
  config.color = true

  config.around(:each) do |example|
    silence_stream(STDOUT) do
      silence_stream(STDERR) do
        example.run
      end
    end
  end
end
