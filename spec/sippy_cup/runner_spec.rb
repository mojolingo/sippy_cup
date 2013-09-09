require 'sippy_cup/runner'

describe SippyCup::Runner do
  describe '#run' do
    context "System call fails/doesn't fail" do
      let(:settings) { Hash.new }
      let(:command) { "sudo sipp -i 127.0.0.1" }
      let(:pid) { '1234' }

      subject { SippyCup::Runner.new settings }
      it 'should raise an error when the system call fails' do
        subject.logger.stub :info
        subject.should_receive(:prepare_command).and_return command
        subject.should_receive(:spawn).with(command).and_raise(Errno::ENOENT)
        Process.stub :wait2
        subject.stub :process_exit_status
        lambda {subject.run}.should raise_error Errno::ENOENT
      end

      it 'should not raise an error when the system call is successful' do
        subject.logger.stub :info
        subject.should_receive(:prepare_command).and_return command
        subject.should_receive(:spawn).with(command).and_return pid
        Process.stub :wait2
        subject.stub :process_exit_status
        lambda {subject.run}.should_not raise_error
      end
    end

    context "specifying a stats file" do
      let(:settings) { { stats_file: 'stats.csv' } }
      let(:command) { "sudo sipp -i 127.0.0.1 -trace_stats -stf stats.csv" }
      let(:pid) { '1234' }

      subject { SippyCup::Runner.new settings }
      it 'should display the path to the csv file when one is specified' do
        subject.logger.should_receive(:info).twice
        subject.should_receive(:prepare_command).and_return command
        subject.should_receive(:spawn).with(command).and_return pid
        Process.stub :wait2
        subject.stub :process_exit_status
        subject.logger.should_receive(:info).with "Statistics logged at #{File.expand_path settings[:stats_file]}"
        subject.run
      end
    end

    context "no stats file" do
      let(:settings) { Hash.new }
      let(:command) { "sudo sipp -i 127.0.0.1" }
      let(:pid) { '1234' }

      subject { SippyCup::Runner.new settings }
      it 'should not display a csv file path if none is specified' do
        subject.logger.should_receive(:info).ordered.with(/Preparing to run SIPp command/)
        subject.logger.should_receive(:info).ordered.with(/Test completed successfully/)
        subject.should_receive(:prepare_command).and_return command
        subject.should_receive(:spawn).with(command).and_return pid
        Process.stub :wait2
        subject.stub :process_exit_status
        subject.run
      end
    end

    context "CSV file" do
      let(:settings) { {scenario_variables: "/path/to/csv", scenario: "/path/to/scenario", source: "127.0.0.1",
                        destination: "127.0.0.1", max_concurrent: 5, calls_per_second: 5,
                        number_of_calls: 5} }
      let(:pid) { "1234" }

      subject { SippyCup::Runner.new settings }
      it 'should use CSV into the test run' do
        subject.logger.should_receive(:info).ordered.with(/Preparing to run SIPp command/)
        subject.logger.should_receive(:info).ordered.with(/Test completed successfully/)
        subject.should_receive(:spawn).with(/\-inf \/path\/to\/csv/)
        Process.stub :wait2
        subject.stub :process_exit_status
        subject.run
      end
    end

    context "Evaluating SIPp exit code" do
      let(:settings) { Hash.new }
      let(:command) { "sudo sipp -i 127.0.0.1" }
      let(:pid) { '1234' }

      subject { SippyCup::Runner.new settings }

      it 'should return false when the SIPp exit code is 1 and log appropriately' do
        subject.logger.stub :info
        subject.should_receive(:prepare_command).and_return command
        subject.should_receive(:spawn).with(command).and_return pid
        Process.should_receive(:wait2).and_return([nil, double(exitstatus: 1)])
        subject.logger.should_receive(:info).ordered.with(/Test completed successfully but some calls failed./)
        subject.run.should == false
      end
    end

  end

  describe '#stop' do
    let(:settings) { Hash.new }
    let(:command) { "sudo sipp -i 127.0.0.1" }
    let(:pid) { '1234' }

    subject { SippyCup::Runner.new settings }

    it "should try to kill the SIPp process if there is a PID" do
      subject.sipp_pid = pid
      Process.should_receive(:kill).with("KILL", pid)
      subject.stop
    end

    it "should not try to kill the SIPp process if there is a PID" do
      subject.sipp_pid = nil
      Process.should_receive(:kill).never
      subject.stop
    end

    it "should raise a Errno::ESRCH if the PID does not exist" do
      subject.sipp_pid = pid
      Process.should_receive(:kill).with("KILL", pid).and_raise(Errno::ESRCH)
      expect { subject.stop }.to raise_error Errno::ESRCH
    end

    it "should raise a Errno::EPERM if the user has no permission to kill the process" do
      subject.sipp_pid = pid
      Process.should_receive(:kill).with("KILL", pid).and_raise(Errno::EPERM)
      expect { subject.stop }.to raise_error Errno::EPERM
    end
  end

  describe '#process_exit_status' do
    let(:settings) { Hash.new }
    let(:process_status) { [nil, double(exitstatus: exitstatus)] }

    subject { SippyCup::Runner.new settings }

    context "with normal operation" do
      let(:exitstatus) { 0 }
      it "should not raise anything if SIPp returns 0" do
        expect {subject.process_exit_status(process_status)}.to_not raise_error
      end
    end

    context "with at least one call failure" do
      let(:exitstatus) { 1 }
      it "should return false if SIPp returns 1" do
        subject.process_exit_status(process_status).should == false
      end
    end

    context "with an exit from inside SIPp" do
      let(:exitstatus) { 97 }
      it "should raise a ExitOnInternalCommand error if SIPp returns 97" do
        expect {subject.process_exit_status(process_status)}.to raise_error SippyCup::ExitOnInternalCommand
      end
    end

    context "with no calls processed" do
      let(:exitstatus) { 99 }
      it "should raise a NoCallsProcessed error if SIPp returns 99" do
        expect {subject.process_exit_status(process_status)}.to raise_error SippyCup::NoCallsProcessed
      end
    end

    context "with a fatal error" do
      let(:exitstatus) { -1 }
      it "should raise a FatalError error if SIPp returns -1" do
        expect {subject.process_exit_status(process_status)}.to raise_error SippyCup::FatalError
      end
    end

    context "with a socket binding fatal error" do
      let(:exitstatus) { -2 }
      it "should raise a FatalSocketBindingError error if SIPp returns -2" do
        expect {subject.process_exit_status(process_status)}.to raise_error SippyCup::FatalSocketBindingError
      end
    end

    context "with a generic undocumented fatal error" do
      let(:exitstatus) { 255 }
      it "should raise a SippGenericError error if SIPp returns 255" do
        expect {subject.process_exit_status(process_status)}.to raise_error SippyCup::SippGenericError
      end
    end
  end
end
