# encoding: utf-8
require 'spec_helper'

describe SippyCup::Runner do
  before do
    Dir.chdir "/tmp"
  end

  let(:settings) { {} }
  let(:default_settings) { { logger: logger } }
  let(:command) { "sudo $(which sipp) -i 127.0.0.1" }
  let(:pid) { '1234' }

  let(:logger) { double }

  before { logger.stub :info }

  let(:manifest) do
    <<-MANIFEST
name: foobar
source: 'dah.com'
destination: 'bar.com'
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
    MANIFEST
  end
  let(:scenario) { SippyCup::Scenario.from_manifest manifest }

  subject { SippyCup::Runner.new scenario, default_settings.merge(settings) }

  def expect_command_execution(command = anything)
    Process.stub :wait2
    subject.stub :process_exit_status

    subject.should_receive(:spawn).with(command, anything)
  end

  describe '#run' do
    it "executes the correct command to invoke SIPp" do
      full_scenario_path = File.join(Dir.tmpdir, '/scenario.*')
      expect_command_execution %r{sudo \$\(which sipp\) -p 8836 -sf #{full_scenario_path} -i dah.com bar.com}
      subject.run
    end

    it "ensures that input files are not left on the filesystem" do
      FakeFS do
        Dir.mkdir("/tmp") unless Dir.exist?("/tmp")
        expect_command_execution.and_raise
        expect { subject.run }.to raise_error
        Dir.entries(Dir.tmpdir).should eql(['.', '..'])
      end
    end

    context "System call fails/doesn't fail" do
      it 'raises an error when the system call fails' do
        expect_command_execution.and_raise(Errno::ENOENT)
        expect { subject.run }.to raise_error Errno::ENOENT
      end

      it 'does not raise an error when the system call is successful' do
        expect_command_execution
        expect { subject.run }.not_to raise_error
      end
    end

    context "async" do
      let(:settings) { {async: true} }
      it 'should not wait for SIPp to terminate' do
        subject.stub :process_exit_status
        subject.should_receive :spawn
        Process.should_not_receive :wait2
        subject.run
      end
    end

    context "specifying outbound options in the manifest" do
      let(:manifest) do
        <<-MANIFEST
name: foobar
source: 'dah.com'
destination: 'bar.com'
to_user: 1
concurrent_max: 5
calls_per_second: 2
number_of_calls: 10
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
        MANIFEST
      end

      it 'should pass the appropriate options to sipp' do
        expect_command_execution(/-l 5 -m 10 -r 2 -s 1/)
        subject.run
      end
    end

    context "specifying arbitrary options in the manifest" do
      let(:manifest) do
        <<-MANIFEST
name: foobar
source: 'dah.com'
destination: 'bar.com'
concurrent_max: 5
calls_per_second: 2
number_of_calls: 10
options:
  trace_err: ~
  foo: bar
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
        MANIFEST
      end

      it 'should pass the options to sipp' do
        expect_command_execution(/-trace_err -foo bar/)
        subject.run
      end
    end

    context "specifying a source port in the manifest" do
      let(:manifest) do
        <<-MANIFEST
name: foobar
source: 'dah.com'
destination: 'bar.com'
concurrent_max: 5
calls_per_second: 2
number_of_calls: 10
source_port: 1234
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
        MANIFEST
      end

      it 'should set the -p option' do
        expect_command_execution(/-p 1234/)
        subject.run
      end
    end

    context "specifying a to_user in the Scenario" do
      let(:manifest) do
        <<-MANIFEST
name: foobar
source: 'dah.com'
destination: 'bar.com'
concurrent_max: 5
calls_per_second: 2
number_of_calls: 10
from_user: pat
to_user: frank
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
        MANIFEST
      end

      it 'should set the -s option' do
        expect_command_execution(/-s frank/)
        subject.run
      end
    end

    context "specifying a media port" do
      let(:manifest) do
        <<-MANIFEST
name: foobar
source: 'dah.com'
destination: 'bar.com'
concurrent_max: 5
calls_per_second: 2
number_of_calls: 10
media_port: 6000
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
        MANIFEST
      end

      it 'should set the -mp option' do
        expect_command_execution(/-mp 6000/)
        subject.run
      end
    end

    context "specifying a stats file in the manifest" do
      let(:manifest) do
        <<-MANIFEST
name: foobar
source: 'dah.com'
destination: 'bar.com'
concurrent_max: 5
calls_per_second: 2
number_of_calls: 10
stats_file: stats.csv
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
        MANIFEST
      end

      it 'should turn on -trace_stats, set the -stf option to the filename provided, and set the stats interval to 1 second' do
        expect_command_execution(/-trace_stat -stf stats.csv -fd 1/)
        subject.run
      end

      context 'with a stats interval provided' do
        let(:manifest) do
          <<-MANIFEST
name: foobar
source: 'dah.com'
destination: 'bar.com'
concurrent_max: 5
calls_per_second: 2
number_of_calls: 10
stats_file: stats.csv
stats_interval: 3
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
          MANIFEST
        end

        it "passes the interval to the -fd option" do
          expect_command_execution(/-fd 3/)
          subject.run
        end
      end

      it 'logs the path to the csv file' do
        expect_command_execution
        logger.should_receive(:info).with "Statistics logged at #{File.expand_path('stats.csv')}"
        subject.run
      end
    end

    context "no stats file" do
      it 'does not log a statistics file path' do
        logger.should_receive(:info).with(/Statistics logged at/).never
        expect_command_execution
        subject.run
      end
    end

    context "specifying a summary report file in the manifest" do
      let(:manifest) do
        <<-MANIFEST
name: foobar
source: 'dah.com'
destination: 'bar.com'
concurrent_max: 5
calls_per_second: 2
number_of_calls: 10
summary_report_file: report.txt
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
        MANIFEST
      end

      it 'should turn on -trace_screen and set the -screen_file option to the filename provided' do
        expect_command_execution(/-trace_screen -screen_file report.txt/)
        subject.run
      end
    end

    context "specifying a errors report file in the manifest" do
      let(:manifest) do
        <<-MANIFEST
name: foobar
source: 'dah.com'
destination: 'bar.com'
concurrent_max: 5
calls_per_second: 2
number_of_calls: 10
errors_report_file: errors.txt
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
        MANIFEST
      end

      it 'should turn on -trace_err and set the -error_file option to the filename provided' do
        expect_command_execution(/-trace_err -error_file errors.txt/)
        subject.run
      end
    end

    context "specifying rate increase options" do
      let(:manifest) do
        <<-MANIFEST
name: foobar
source: 'dah.com'
destination: 'bar.com'
concurrent_max: 5
calls_per_second: 2
calls_per_second_max: 5
calls_per_second_incr: 2
calls_per_second_interval: 20
number_of_calls: 10
errors_report_file: errors.txt
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
        MANIFEST
      end

      it 'should not terminate the test when reaching the rate limit and set the rate limit and increase appropriately' do
        expect_command_execution(/-no_rate_quit -rate_max 5 -rate_increase 2 -rate_interval 20/)
        subject.run
      end
    end

    context "specifying a variables file" do
      let(:manifest) do
        <<-MANIFEST
name: foobar
source: 'dah.com'
destination: 'bar.com'
concurrent_max: 5
calls_per_second: 2
number_of_calls: 10
scenario_variables: /path/to/vars.csv
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
        MANIFEST
      end

      it 'uses CSV in the test run' do
        logger.should_receive(:info).ordered.with(/Preparing to run SIPp command/)
        logger.should_receive(:info).ordered.with(/Test completed successfully/)
        expect_command_execution(%r{-inf /path/to/vars.csv})
        subject.run
      end
    end

    context 'with a transport mode specified' do
      let(:manifest) do
        <<-MANIFEST
name: foobar
source: 'dah.com'
destination: 'bar.com'
concurrent_max: 5
calls_per_second: 2
number_of_calls: 10
transport_mode: t1
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
        MANIFEST
      end

      it "passes the transport mode to the -t option" do
        expect_command_execution(/-t t1/)
        subject.run
      end
    end

    describe 'SIPp exit status handling' do
      let(:error_string) { "Some error" }
      let(:exit_code) { 255 }
      let(:command) { "sh -c 'echo \"#{error_string}\" 1>&2; exit #{exit_code}'" }

      let(:settings) { { command: command } }

      context "with normal operation" do
        let(:exit_code) { 0 }

        it "doesn't raise anything if SIPp returns 0" do
          quietly do
            subject.run.should be true
          end
        end
      end

      context "with at least one call failure" do
        let(:exit_code) { 1 }

        it "returns false if SIPp returns 1" do
          quietly do
            logger.should_receive(:info).ordered.with(/Test completed successfully but some calls failed./)
            subject.run.should be false
          end
        end
      end

      context "with an exit from inside SIPp" do
        let(:exit_code) { 97 }

        it "raises a ExitOnInternalCommand error if SIPp returns 97" do
          quietly do
            expect { subject.run }.to raise_error SippyCup::ExitOnInternalCommand, error_string
          end
        end
      end

      context "with no calls processed" do
        let(:exit_code) { 99 }

        it "raises a NoCallsProcessed error if SIPp returns 99" do
          quietly do
            expect { subject.run }.to raise_error SippyCup::NoCallsProcessed, error_string
          end
        end
      end

      context "with a fatal error" do
        let(:exit_code) { 255 }

        it "raises a FatalError error if SIPp returns 255" do
          quietly do
            expect { subject.run }.to raise_error SippyCup::FatalError, error_string
          end
        end
      end

      context "with a socket binding fatal error" do
        let(:exit_code) { 254 }

        it "raises a FatalSocketBindingError error if SIPp returns 254" do
          quietly do
            expect { subject.run }.to raise_error SippyCup::FatalSocketBindingError, error_string
          end
        end
      end

      context "with a generic undocumented fatal error" do
        let(:exit_code) { 128 }

        it "raises a SippGenericError error if SIPp returns 255" do
          quietly do
            expect { subject.run }.to raise_error SippyCup::SippGenericError, error_string
          end
        end

        it "raises a SippGenericError error with the appropriate message" do
          quietly do
            expect { subject.run }.to raise_error SippyCup::SippGenericError, error_string
          end
        end
      end
    end

    describe "SIPp stdout/stderr" do
      let(:output_string) { "Some output" }
      let(:error_string) { "Some error" }
      let(:command) { "sh -c 'echo \"#{output_string}\"' && sh -c 'echo \"#{error_string}\" 1>&2'" }

      let(:settings) { { command: command } }

      def active_thread_count
        Thread.list.select { |t| t.status != 'aborting' }.size
      end

      context "by default" do
        it "proxies stdout to the terminal" do
          quietly do
            capture(:stdout) { subject.run }.strip.should == output_string
          end
        end

        it "proxies stderr to the terminal" do
          quietly do
            capture(:stderr) { subject.run }.strip.should == error_string
          end
        end

        it "does not leak threads" do
          Thread.list.each { |t| t.kill unless t = Thread.main }
          sleep 0.1
          original_thread_count = active_thread_count
          quietly do
            subject.run
          end
          sleep 0.1
          active_thread_count.should == original_thread_count
        end
      end

      context "with :full_sipp_output disabled" do
        let(:settings) { { command: command, full_sipp_output: false } }

        it "swallows stdout from SIPp" do
          capture(:stdout) { subject.run }.should == ''
        end

        it "swallows stderr from SIPp" do
          capture(:stderr) { subject.run }.should == ''
        end

        it "does not leak threads" do
          quietly do
            Thread.list.each { |t| t.kill unless t = Thread.main }
            sleep 0.1
            original_thread_count = active_thread_count
            subject.run
            sleep 0.1
            active_thread_count.should == original_thread_count
          end
        end
      end
    end
  end

  describe '#wait' do
    before { subject.sipp_pid = pid }
    it "waits for the SIPp process" do
      Process.should_receive(:wait2).with pid.to_i
      subject.should_receive(:process_exit_status)
      subject.should_receive(:cleanup_input_files)
      subject.wait
    end

    context "async" do
      subject { SippyCup::Runner.new scenario, logger: logger, async: true }
      it "waits for the SIPp process and cleans up input files" do
        Process.should_receive(:wait2).with pid.to_i
        subject.should_receive(:process_exit_status)
        subject.should_receive(:cleanup_input_files)
        subject.wait
      end
    end
  end

  describe '#stop' do
    before { subject.sipp_pid = pid }

    it "tries to kill the SIPp process if there is a PID" do
      Process.should_receive(:kill).with("KILL", pid)
      subject.stop
    end

    context "if there is no PID available" do
      let(:pid) { nil }

      it "doesn't try to kill the SIPp process" do
        Process.should_receive(:kill).never
        subject.stop
      end
    end

    it "raises a Errno::ESRCH if the PID does not exist" do
      Process.should_receive(:kill).with("KILL", pid).and_raise(Errno::ESRCH)
      expect { subject.stop }.to raise_error Errno::ESRCH
    end

    it "raises a Errno::EPERM if the user has no permission to kill the process" do
      Process.should_receive(:kill).with("KILL", pid).and_raise(Errno::EPERM)
      expect { subject.stop }.to raise_error Errno::EPERM
    end
  end
end
