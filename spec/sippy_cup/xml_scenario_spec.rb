require 'spec_helper'

describe SippyCup::XMLScenario do
  include FakeFS::SpecHelpers

  before do
    Dir.mkdir("/tmp") unless Dir.exist?("/tmp")
    Dir.chdir "/tmp"
  end

  let(:default_args) { {source: '127.0.0.1:5060', destination: '10.0.0.1:5080'} }
  let(:args) { {} }

  let(:xml) do
    <<-XML
<?xml version="1.0"?>
<scenario name="Test">
  <send retrans="500">
    <![CDATA[
    INVITE sip:[service]@[remote_ip]:[remote_port] SIP/2.0
    Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
    From: "sipp" <sip:sipp@[local_ip]>;tag=[call_number]
    To: <sip:[service]@[remote_ip]:[remote_port]>
    Call-ID: [call_id]
    CSeq: [cseq] INVITE
    Contact: <sip:sipp@[local_ip]:[local_port];transport=[transport]>
    Max-Forwards: 100
    User-Agent: SIPp/sippy_cup
    Content-Type: application/sdp
    Content-Length: [len]

    v=0
    o=user1 53655765 2353687637 IN IP[local_ip_type] [local_ip]
    s=-
    c=IN IP[media_ip_type] [media_ip]
    t=0 0
    m=audio [media_port] RTP/AVP 0 101
    a=rtpmap:0 PCMU/8000
    a=rtpmap:101 telephone-event/8000
    a=fmtp:101 0-15
    ]]>
  </send>
</scenario>
    XML
  end
  let(:media) do
    FakeFS.deactivate!
    media = File.read(File.expand_path('dtmf_2833_1.pcap', File.join(File.dirname(__FILE__), '..', 'fixtures')), mode: 'rb')
    FakeFS.activate!
    media
  end

  subject(:scenario) { described_class.new 'Test', xml, media, default_args.merge(args) }

  describe "#to_xml" do
    it "should return the XML representation of the scenario" do
      subject.to_xml.should == xml
    end
  end

  describe "#to_tmpfiles" do
    it "writes the scenario XML to a Tempfile and returns it" do
      files = scenario.to_tmpfiles
      files[:scenario].should be_a(Tempfile)
      files[:scenario].read.should eql(xml)
    end

    it "allows the scenario XML to be read from disk independently" do
      files = scenario.to_tmpfiles
      File.read(files[:scenario].path).should eql(xml)
    end

    it "writes the PCAP media to a Tempfile and returns it" do
      files = scenario.to_tmpfiles
      files[:media].should be_a(Tempfile)
      files[:media].read.should eql(media)
    end

    it "allows the PCAP media to be read from disk independently" do
      files = scenario.to_tmpfiles
      File.read(files[:media].path).should eql(media)
    end

    context "when media is not provided" do
      let(:media) { nil }

      it "should not create a media file" do
        files = scenario.to_tmpfiles
        files[:media].should be_nil
      end
    end
  end

  describe "#scenario_options" do
    it "should return options passed to the initializer" do
      scenario.scenario_options.should == {
        name: 'Test',
        source: '127.0.0.1:5060',
        destination: '10.0.0.1:5080'
      }
    end
  end
end
