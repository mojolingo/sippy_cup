require 'yaml'
require 'active_support/core_ext/hash'

module SippyCup
  class Runner
    attr_accessor :sipp_pid

    def initialize(opts = {})
      @options = ActiveSupport::HashWithIndifferentAccess.new opts
    end

    def compile
      raise ArgumentError, "Must provide scenario steps" unless @options[:steps]
      scenario = SippyCup::Scenario.new @options[:name].titleize, source: @options[:source], destination: @options[:destination]
      @options[:steps].each do |step|
        instruction, arg = step.split ' ', 2
        if arg && !arg.empty?
          # Strip leading/trailing quotes if present
          arg.gsub!(/^'|^"|'$|"$/, '')
          scenario.send instruction.to_sym, arg
        else
          scenario.send instruction
        end
      end
      scenario.compile!
    end

    def prepare_command
      [:scenario, :source, :destination, :max_concurrent, :calls_per_second, :number_of_calls].each do |arg|
        raise ArgumentError, "Must provide #{arg}!" unless @options[arg]
      end
      command = "sudo sipp"
      source_port = @options[:source_port] || '8836'
      sip_user = @options[:sip_user] || '1'
      command << " -i #{@options[:source]} -p #{source_port} -sf #{File.expand_path @options[:scenario]}.xml"
      command << " -l #{@options[:max_concurrent]} -m #{@options[:number_of_calls]} -r #{@options[:calls_per_second]}"
      command << " -s #{sip_user}"
      if @options[:stats_file]
        stats_interval = @options[:stats_interval] || 1
        command << " -trace_stat -stf #{@options[:stats_file]} -fd #{stats_interval}"
      end
      command << " #{@options[:destination]}"
      command << " > /dev/null 2>&1" unless @options[:full_sipp_output]
      command
    end

    def run
      command = prepare_command
      p "Preparing to run SIPp command: #{command}" unless @options[:full_sipp_output]

      begin
        @sipp_pid = spawn command
        Process.wait @sipp_pid
      rescue Exception => e
        raise RuntimeError, "Command #{command} failed"
      end

      unless @options[:full_sipp_output]
        p "Test completed successfully!" 
        p "Statistics logged at #{File.expand_path @options[:stats_file]}" if @options[:stats_file]
      end
    end

    def stop
      Process.kill "KILL", @sipp_pid if @sipp_pid
    rescue Exception => e
      raise RuntimeError, "Killing #{@sipp_pid} failed"
    end
  end
end
