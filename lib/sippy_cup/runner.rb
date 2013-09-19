require 'logger'
require 'active_support/core_ext/hash'

module SippyCup
  class Runner
    attr_accessor :sipp_pid

    def initialize(opts = {})
      defaults = { full_sipp_output: true }
      @options = ActiveSupport::HashWithIndifferentAccess.new defaults.merge(opts)

      @command = @options[:command]

      [:scenario, :source, :destination, :max_concurrent, :calls_per_second, :number_of_calls].each do |arg|
        raise ArgumentError, "Must provide #{arg}!" unless @options[arg]
      end

      @logger = @options[:logger] || Logger.new(STDOUT)
    end

    def compile
      scenario_opts = {source: @options[:source], destination: @options[:destination]}
      scenario_opts[:filename] = @options[:filename] if @options[:filename]
      scenario = SippyCup::Scenario.new @options[:name].titleize, scenario_opts
      scenario.build @options[:steps]
      scenario.compile!
    end

    # Runs the loaded scenario using SIPp
    #
    # @raises Errno::ENOENT when the SIPp executable cannot be found
    # @raises SippyCup::ExitOnInternalCommand when SIPp exits on an internal command. Calls may have been processed
    # @raises SippyCup::NoCallsProcessed when SIPp exit normally, but has processed no calls
    # @raises SippyCup::FatalError when SIPp encounters a fatal failure
    # @raises SippyCup::FatalSocketBindingError when SIPp fails to bind to the specified socket
    # @raises SippyCup::SippGenericError when SIPp encounters another type of error
    #
    # @return Boolean true if execution succeeded without any failed calls, false otherwise
    #
    def run
      @logger.info "Preparing to run SIPp command: #{command}"

      exit_status, stderr_buffer = execute_with_redirected_streams

      final_result = process_exit_status exit_status, stderr_buffer

      if final_result
        @logger.info "Test completed successfully!"
      else
        @logger.info "Test completed successfully but some calls failed."
      end
      @logger.info "Statistics logged at #{File.expand_path @options[:stats_file]}" if @options[:stats_file]

      final_result
    end

    #
    # Tries to stop SIPp by killing the target PID
    #
    # @raises Errno::ESRCH when the PID does not correspond to a known process
    # @raises Errno::EPERM when the process referenced by the PID cannot be killed
    #
    def stop
      Process.kill "KILL", @sipp_pid if @sipp_pid
    end

  private

    def command
      @command ||= begin
        command = "sudo sipp"
        command_options.each_pair do |key, value|
          command << (value ? " -#{key} #{value}" : " -#{key}")
        end
        command << " #{@options[:destination]}"
      end
    end

    def command_options
      options = {
        i: @options[:source],
        p: @options[:source_port] || '8836',
        sf: "#{File.expand_path @options[:scenario]}.xml",
        l: @options[:max_concurrent],
        m: @options[:number_of_calls],
        r: @options[:calls_per_second],
        s: @options[:sip_user] || '1'
      }

      options[:mp] = @options[:media_port] if @options[:media_port]
      
      if @options[:stats_file]
        options[:trace_stat] = nil
        options[:stf] = @options[:stats_file]
        options[:fd] = @options[:stats_interval] || 1
      end

      if @options[:transport_mode]
        options[:t] = @options[:transport_mode]
      end

      if @options[:scenario_variables]
        options[:inf] = @options[:scenario_variables]
      end

      options
    end

    def execute_with_redirected_streams
      rd, wr = IO.pipe
      stdout_target = @options[:full_sipp_output] ? $stdout : '/dev/null'

      @sipp_pid = spawn command, err: wr, out: stdout_target

      stderr_buffer = String.new

      Thread.new do
        wr.close
        until rd.eof?
          buffer = rd.readpartial(1024).strip
          stderr_buffer += buffer
          $stderr << buffer if @options[:full_sipp_output]
        end
      end

      exit_status = Process.wait2 @sipp_pid.to_i

      rd.close

      [exit_status, stderr_buffer]
    end

    def process_exit_status(process_status, error_message = nil)
      exit_code = process_status[1].exitstatus
      case exit_code
      when 0
        true
      when 1
        false
      when 97
        raise SippyCup::ExitOnInternalCommand, error_message
      when 99
        raise SippyCup::NoCallsProcessed, error_message
      when 255
        raise SippyCup::FatalError, error_message
      when 254
        raise SippyCup::FatalSocketBindingError, error_message
      else
        raise SippyCup::SippGenericError, error_message
      end
    end
  end

  # The corresponding SIPp error code is listed after the exception
  class Error < StandardError; end
  class ExitOnInternalCommand < Error; end # 97
  class NoCallsProcessed < Error; end # 99
  class FatalError < Error; end # -1
  class FatalSocketBindingError < Error; end # -2
  class SippGenericError < Error; end # 255 and undocumented errors
end
