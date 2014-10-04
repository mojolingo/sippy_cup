# encoding: utf-8
require 'logger'

#
# Service object to oversee the execution of a Scenario
#
module SippyCup
  class Runner
    attr_accessor :sipp_pid

    #
    # Create a runner from a scenario
    #
    # @param [Scenario, XMLScenario] scenario The scenario to execute
    # @param [Hash] opts Options to modify the runner
    # @option opts [optional, true, false] :full_sipp_output Whether or not to copy SIPp's stdout/stderr to the parent process. Defaults to true.
    # @option opts [optional, Logger] :logger A logger to use in place of the internal logger to STDOUT.
    # @option opts [optional, String] :command The command to execute. This is mostly available for testing.
    #
    def initialize(scenario, opts = {})
      @scenario = scenario
      @scenario_options = @scenario.scenario_options

      defaults = { full_sipp_output: true }
      @options = defaults.merge(opts)

      @command = @options[:command]
      @logger = @options[:logger] || Logger.new(STDOUT)
    end

    #
    # Runs the loaded scenario using SIPp
    #
    def run
      @input_files = @scenario.to_tmpfiles

      @logger.info "Preparing to run SIPp command: #{command}"

      execute_with_redirected_streams

      wait unless @options[:async]
    ensure
      cleanup_input_files unless @options[:async]
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

    #
    # Waits for the runner to finish execution
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
    def wait
      exit_status = Process.wait2 @sipp_pid.to_i
      @rd.close if @rd
      final_result = process_exit_status exit_status, @stderr_buffer
      if final_result
        @logger.info "Test completed successfully!"
      else
        @logger.info "Test completed successfully but some calls failed."
      end
      @logger.info "Statistics logged at #{File.expand_path @scenario_options[:stats_file]}" if @scenario_options[:stats_file]

      final_result
    ensure
      cleanup_input_files
    end

  private

    def command
      @command ||= begin
        command = "sudo $(which sipp)"
        command_options.each_pair do |key, value|
          command << (value ? " -#{key} #{value}" : " -#{key}")
        end
        command << " #{@scenario_options[:destination]}"
      end
    end

    def command_options
      options = {
        p: @scenario_options[:source_port] || '8836',
        sf: @input_files[:scenario].path,
        l: @scenario_options[:max_concurrent] || 5,
        m: @scenario_options[:number_of_calls] || 10,
        r: @scenario_options[:calls_per_second] || 10,
        s: @scenario_options[:to_user] || '1'
      }

      options[:i] = @scenario_options[:source] if @scenario_options[:source]
      options[:mp] = @scenario_options[:media_port] if @scenario_options[:media_port]

      if @scenario_options[:stats_file]
        options[:trace_stat] = nil
        options[:stf] = @scenario_options[:stats_file]
        options[:fd] = @scenario_options[:stats_interval] || 1
      end

      if @scenario_options[:transport_mode]
        options[:t] = @scenario_options[:transport_mode]
      end

      if @scenario_options[:scenario_variables]
        options[:inf] = @scenario_options[:scenario_variables]
      end

      options.merge! @scenario_options[:options] if @scenario_options[:options]

      options
    end

    def execute_with_redirected_streams
      @rd, wr = IO.pipe
      stdout_target = @options[:full_sipp_output] ? $stdout : '/dev/null'

      @sipp_pid = spawn command, err: wr, out: stdout_target

      @stderr_buffer = String.new

      Thread.new do
        wr.close
        until @rd.eof?
          buffer = @rd.readpartial(1024).strip
          @stderr_buffer += buffer
          $stderr << buffer if @options[:full_sipp_output]
        end
      end
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

    def cleanup_input_files
      @input_files.values.compact.each do |value|
        value.close
        value.unlink
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
