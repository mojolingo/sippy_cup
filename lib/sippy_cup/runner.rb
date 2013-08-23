require 'yaml'
require 'active_support/core_ext/hash'

module SippyCup
  class Runner
    def initialize(opts = {})
      @options = ActiveSupport::HashWithIndifferentAccess.new opts
    end

    def prepare_command
      [:scenario, :source, :destination, :max_concurrent, :calls_per_second, :number_of_calls].each do |arg|
        raise "Must provide #{arg}!" unless @options[arg]
      end
      command = "sudo sipp"
      source_port = @options[:source_port] || '8836'
      sip_user = @options[:sip_user] || '1'
      command << " -i #{@options[:source]} -p #{source_port} -sf #{File.expand_path @options[:scenario]}"
      command << " -l #{@options[:max_concurrent]} -m #{@options[:number_of_calls]} -r #{@options[:calls_per_second]}"
      command << " -s #{sip_user}"
      if @options[:stats_file]
        stats_interval = @options[:stats_interval] || 10
        command << " -trace_stats -stf #{@options[:stats_file]} -fd #{stats_interval}"
      end
      command << " > /dev/null 2>&1" unless @options[:full_sipp_output]
      command
    end

    def run
      command = prepare_command
      p "Preparing to run SIPp command: #{command}"
      result = system command
      raise "SIPp failed! Try running the scenario with the full_sipp_output enabled for more information" unless result
      p "Test completed successfully!"
      p "Statistics logged at #{File.expand_path @options[:stats_file]}" if @options[:stats_file]
    end

  end
end