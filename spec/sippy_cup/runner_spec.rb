require 'sippy_cup/runner'

describe SippyCup::Runner do
  describe '#run' do
    context "System call fails/doesn't fail" do
      let(:settings) { Hash.new }
      let(:command) { "sudo sipp -i 127.0.0.1" }
      let(:pid) { '1234' }

      subject { SippyCup::Runner.new settings }
      it 'should raise an error when the system call fails' do
        subject.stub :p
        subject.should_receive(:prepare_command).and_return command
        subject.should_receive(:spawn).with(command).and_raise(Errno::ENOENT)
        Process.stub :wait
        lambda {subject.run}.should raise_error RuntimeError
      end

      it 'should not raise an error when the system call is successful' do 
        subject.stub :p
        subject.should_receive(:prepare_command).and_return command
        subject.should_receive(:spawn).with(command).and_return pid
        Process.stub :wait
        lambda {subject.run}.should_not raise_error
      end
    end

    context "specifying a stats file" do
      let(:settings) { { stats_file: 'stats.csv' } }
      let(:command) { "sudo sipp -i 127.0.0.1 -trace_stats -stf stats.csv" }
      let(:pid) { '1234' }

      subject { SippyCup::Runner.new settings }
      it 'should display the path to the csv file when one is specified' do
        subject.should_receive(:p).twice
        subject.should_receive(:prepare_command).and_return command
        subject.should_receive(:spawn).with(command).and_return pid
        Process.stub :wait
        subject.should_receive(:p).with "Statistics logged at #{File.expand_path settings[:stats_file]}"
        subject.run
      end
    end

    context "no stats file" do
      let(:settings) { Hash.new }
      let(:command) { "sudo sipp -i 127.0.0.1" }
      let(:pid) { '1234' }

      subject { SippyCup::Runner.new settings }
      it 'should not display a csv file path if none is specified' do
        subject.should_receive(:p).ordered.with(/Preparing to run SIPp command/)
        subject.should_receive(:p).ordered.with(/Test completed successfully/)
        subject.should_receive(:prepare_command).and_return command
        subject.should_receive(:spawn).with(command).and_return pid
        Process.stub :wait
        subject.run
      end
    end

    context "CSV file" do
      let(:settings) { {inf_csv: "/path/to/csv", scenario: "/path/to/scenario", source: "127.0.0.1",
                        destination: "127.0.0.1", max_concurrent: 5, calls_per_second: 5,
                        number_of_calls: 5} }
      let(:pid) { "1234" }

      subject { SippyCup::Runner.new settings }
      it 'should use CSV into the test run' do
        subject.should_receive(:p).ordered.with(/Preparing to run SIPp command/)
        subject.should_receive(:p).ordered.with(/Test completed successfully/)
        subject.should_receive(:spawn).with(/\-inf \/path\/to\/csv/)
        Process.stub :wait
        subject.run
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

    it "should raise a RuntimeError if the PID does not exist" do
      subject.sipp_pid = pid
      Process.should_receive(:kill).with("KILL", pid).and_raise(Errno::ESRCH)
      expect { subject.stop }.to raise_error RuntimeError
    end
  end
end
