require 'sippy_cup/runner'

describe SippyCup::Runner do
  let(:settings) { {} }
  let(:default_settings) do
    {
      logger: logger,
      scenario: 'foobar',
      source: 'doo@dah.com',
      destination: 'foo@bar.com',
      max_concurrent: 5,
      calls_per_second: 2,
      number_of_calls: 10
    }
  end
  let(:command) { "sudo sipp -i 127.0.0.1" }
  let(:pid) { '1234' }

  let(:logger) { double }

  before { logger.stub :info }

  subject { SippyCup::Runner.new default_settings.merge(settings) }

  [
    :scenario,
    :source,
    :destination,
    :max_concurrent,
    :calls_per_second,
    :number_of_calls
  ].each do |attribute|
    context "without a " do
      let(:settings) { { attribute => nil } }

      it "should raise ArgumentError" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  def expect_command_execution(command = anything)
    Process.stub :wait2
    subject.stub :process_exit_status

    subject.should_receive(:spawn).with(command, anything)
  end

  describe '#run' do
    it "should execute the correct command to invoke SIPp" do
      full_scenario_path = File.join(Dir.pwd, 'foobar.xml')
      expect_command_execution "sudo sipp -i doo@dah.com -p 8836 -sf #{full_scenario_path} -l 5 -m 10 -r 2 -s 1 foo@bar.com"
      subject.run
    end

    context "System call fails/doesn't fail" do
      it 'should raise an error when the system call fails' do
        expect_command_execution.and_raise(Errno::ENOENT)
        expect { subject.run }.to raise_error Errno::ENOENT
      end

      it 'should not raise an error when the system call is successful' do
        expect_command_execution
        expect { subject.run }.not_to raise_error
      end
    end

    context "specifying a source port" do
      let(:settings) { { source_port: 1234 } }

      it 'should set the -p option' do
        expect_command_execution(/-p 1234/)
        subject.run
      end
    end

    context "specifying a SIP user" do
      let(:settings) { { sip_user: 'frank' } }

      it 'should set the -s option' do
        expect_command_execution(/-s frank/)
        subject.run
      end
    end

    context "specifying a stats file" do
      let(:settings) { { stats_file: 'stats.csv' } }

      it 'should turn on -trace_stats, set the -stf option to the filename provided, and set the stats interval to 1 second' do
        expect_command_execution(/-trace_stat -stf stats.csv -fd 1/)
        subject.run
      end

      context 'with a stats interval provided' do
        let(:settings) { { stats_file: 'stats.csv', stats_interval: 3 } }

        it "should pass the interval to the -fd option" do
          expect_command_execution(/-fd 3/)
          subject.run
        end
      end

      it 'should log the path to the csv file' do
        expect_command_execution
        logger.should_receive(:info).with "Statistics logged at #{File.expand_path settings[:stats_file]}"
        subject.run
      end
    end

    context "no stats file" do
      it 'should not log a statistics file path' do
        logger.should_receive(:info).with(/Statistics logged at/).never
        expect_command_execution
        subject.run
      end
    end

    context "specifying a variables file" do
      let(:settings) { { scenario_variables: "/path/to/csv" } }

      it 'should use CSV into the test run' do
        logger.should_receive(:info).ordered.with(/Preparing to run SIPp command/)
        logger.should_receive(:info).ordered.with(/Test completed successfully/)
        expect_command_execution(/\-inf \/path\/to\/csv/)
        subject.run
      end
    end

    context 'with a transport mode specified' do
      let(:settings) { { transport_mode: 't1' } }

      it "should pass the transport mode to the -t option" do
        expect_command_execution(/-t t1/)
        subject.run
      end
    end

    describe 'SIPp exit status handling' do
      let(:error_string) { "Some error" }
      let(:exit_code) { 255 }
      let(:command) { "sh -c 'echo \"#{error_string}\" 1>&2; exit #{exit_code}'" }

      before do
        subject.should_receive(:prepare_command).and_return command
      end

      context "with normal operation" do
        let(:exit_code) { 0 }

        it "should not raise anything if SIPp returns 0" do
          quietly do
            subject.run.should be_true
          end
        end
      end

      context "with at least one call failure" do
        let(:exit_code) { 1 }

        it "should return false if SIPp returns 1" do
          quietly do
            logger.should_receive(:info).ordered.with(/Test completed successfully but some calls failed./)
            subject.run.should be_false
          end
        end
      end

      context "with an exit from inside SIPp" do
        let(:exit_code) { 97 }

        it "should raise a ExitOnInternalCommand error if SIPp returns 97" do
          quietly do
            expect { subject.run }.to raise_error SippyCup::ExitOnInternalCommand, error_string
          end
        end
      end

      context "with no calls processed" do
        let(:exit_code) { 99 }

        it "should raise a NoCallsProcessed error if SIPp returns 99" do
          quietly do
            expect { subject.run }.to raise_error SippyCup::NoCallsProcessed, error_string
          end
        end
      end

      context "with a fatal error" do
        let(:exit_code) { 255 }

        it "should raise a FatalError error if SIPp returns 255" do
          quietly do
            expect { subject.run }.to raise_error SippyCup::FatalError, error_string
          end
        end
      end

      context "with a socket binding fatal error" do
        let(:exit_code) { 254 }

        it "should raise a FatalSocketBindingError error if SIPp returns 254" do
          quietly do
            expect { subject.run }.to raise_error SippyCup::FatalSocketBindingError, error_string
          end
        end
      end

      context "with a generic undocumented fatal error" do
        let(:exit_code) { 128 }

        it "should raise a SippGenericError error if SIPp returns 255" do
          quietly do
            expect { subject.run }.to raise_error SippyCup::SippGenericError, error_string
          end
        end

        it "should raise a SippGenericError error with the appropriate message" do
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

      before { subject.should_receive(:prepare_command).and_return command }

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
          original_thread_count = active_thread_count
          quietly do
            subject.run
          end
          active_thread_count.should == original_thread_count
        end
      end

      context "with :full_sipp_output disabled" do
        let(:settings) { { full_sipp_output: false } }

        it "swallows stdout from SIPp" do
          capture(:stdout) { subject.run }.should == ''
        end

        it "swallows stderr from SIPp" do
          capture(:stderr) { subject.run }.should == ''
        end

        it "does not leak threads" do
          quietly do
            original_thread_count = active_thread_count
            subject.run
            active_thread_count.should == original_thread_count
          end
        end
      end
    end
  end

  describe '#stop' do
    before { subject.sipp_pid = pid }

    it "should try to kill the SIPp process if there is a PID" do
      Process.should_receive(:kill).with("KILL", pid)
      subject.stop
    end

    context "if there is no PID available" do
      let(:pid) { nil }

      it "should not try to kill the SIPp process" do
        Process.should_receive(:kill).never
        subject.stop
      end
    end

    it "should raise a Errno::ESRCH if the PID does not exist" do
      Process.should_receive(:kill).with("KILL", pid).and_raise(Errno::ESRCH)
      expect { subject.stop }.to raise_error Errno::ESRCH
    end

    it "should raise a Errno::EPERM if the user has no permission to kill the process" do
      Process.should_receive(:kill).with("KILL", pid).and_raise(Errno::EPERM)
      expect { subject.stop }.to raise_error Errno::EPERM
    end
  end
end
