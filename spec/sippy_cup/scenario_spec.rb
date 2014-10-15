# encoding: utf-8
require 'spec_helper'

describe SippyCup::Scenario do
  include FakeFS::SpecHelpers

  before do
    Dir.mkdir("/tmp") unless Dir.exist?("/tmp")
    Dir.chdir "/tmp"
  end

  let(:default_args) { {source: '127.0.0.1:5060', destination: '10.0.0.1:5080'} }
  let(:args) { {} }

  subject(:scenario) { described_class.new 'Test', default_args.merge(args) }

  it "takes a block to generate a scenario" do
    s = described_class.new 'Test', default_args do
      invite
    end

    s.to_xml.should =~ %r{INVITE sip:\[service\]@\[remote_ip\]:\[remote_port\] SIP/2.0}
  end

  it "allows creating a blank scenario with no block" do
    subject.to_xml.should =~ %r{<scenario name="Test"/>}
  end

  describe '#invite' do
    it "sends an INVITE message" do
      subject.invite

      subject.to_xml.should match(%r{<send .*>})
      subject.to_xml.should match(%r{INVITE})
    end

    it "allows setting options on the send instruction" do
      subject.invite foo: 'bar'

      subject.to_xml.should match(%r{<send foo="bar".*>})
    end

    it "defaults to retrans of 500" do
      subject.invite
      subject.to_xml.should match(%r{<send retrans="500".*>})
    end

    it "allows setting retrans" do
      subject.invite retrans: 200
      subject.to_xml.should match(%r{<send retrans="200".*>})
    end

    context "with extra headers specified" do
      it "adds the headers to the end of the message" do
        subject.invite headers: "Foo: <bar>\nBar: <baz>"
        subject.to_xml.should match(%r{Foo: <bar>\nBar: <baz>})
      end

      it "only has one blank line between headers and SDP" do
        subject.invite headers: "Foo: <bar>\n\n\n"
        subject.to_xml.should match(%r{Foo: <bar>\n\nv=0})
      end
    end

    context "with no extra headers" do
      it "only has one blank line between headers and SDP" do
        subject.invite
        subject.to_xml.should match(%r{Content-Length: \[len\]\n\nv=0})
      end
    end

    it "uses [media_port+1] as the RTCP port in the SDP" do
      subject.invite
      subject.to_xml.should match(%r{m=audio \[media_port\] RTP/AVP 0 101\n})
    end

    context "when a from user is specified" do
      let(:args) { {from_user: 'frank'} }

      it "includes the specified user in the From and Contact headers" do
        subject.invite
        subject.to_xml.should match(%r{From: "frank" <sip:frank@})
        subject.to_xml.should match(%r{Contact: <sip:frank@})
      end
    end

    context "when no from user is specified" do
      it "uses a default of 'sipp' in the From and Contact headers" do
        subject.invite
        subject.to_xml.should match(%r{From: "sipp" <sip:sipp@})
        subject.to_xml.should match(%r{Contact: <sip:sipp@})
      end
    end
  end

  describe "#register" do
    it "sends a REGISTER message" do
      subject.register 'frank'

      subject.to_xml.should match(%r{<send .*>})
      subject.to_xml.should match(%r{REGISTER})
    end

    it "allows setting options on the send instruction" do
      subject.register 'frank', nil, foo: 'bar'
      subject.to_xml.should match(%r{<send foo="bar".*>})
    end

    it "defaults to retrans of 500" do
      subject.register 'frank'
      subject.to_xml.should match(%r{<send retrans="500".*>})
    end

    it "allows setting retrans" do
      subject.register 'frank', nil, retrans: 200
      subject.to_xml.should match(%r{<send retrans="200".*>})
    end

    context "when a domain is provided" do
      it "uses the specified user and domain" do
        subject.register 'frank@foobar.com'
        subject.to_xml.should match(%r{REGISTER sip:foobar.com})
        subject.to_xml.should match(%r{From: <sip:frank@foobar.com})
        subject.to_xml.should match(%r{To: <sip:frank@foobar.com})
        subject.to_xml.should match(%r{Contact: <sip:sipp@\[local_ip\]})
      end
    end

    context "when a domain is not provided" do
      it "uses the remote IP" do
        subject.register 'frank'
        subject.to_xml.should match(%r{REGISTER sip:\[remote_ip\]})
        subject.to_xml.should match(%r{From: <sip:frank@\[remote_ip\]})
        subject.to_xml.should match(%r{To: <sip:frank@\[remote_ip\]})
        subject.to_xml.should match(%r{Contact: <sip:sipp@\[local_ip\]})
      end
    end

    context "when a password is provided" do
      it "expects a 401 response" do
        subject.register 'frank', 'abc123'
        subject.to_xml.should match(%r{<recv response="401" auth="true" optional="false"/>})
      end

      it "adds authentication data to the REGISTER message" do
        subject.register 'frank', 'abc123'
        subject.to_xml.should match(%r{\[authentication username=frank password=abc123\]})
      end
    end
  end

  describe '#receive_trying' do
    it "expects an optional 100" do
      subject.receive_trying

      scenario.to_xml.should match(%q{<recv response="100" optional="true"/>})
    end

    it "allows passing options to the recv expectation" do
      subject.receive_trying foo: 'bar'

      scenario.to_xml.should match(%q{<recv foo="bar" response="100" optional="true"/>})
    end

    it "allows overriding options" do
      subject.receive_trying optional: false

      scenario.to_xml.should match(%q{<recv optional="false" response="100"/>})
    end
  end

  describe '#receive_ringing' do
    it "expects an optional 180" do
      subject.receive_ringing

      scenario.to_xml.should match(%q{<recv response="180" optional="true"/>})
    end

    it "allows passing options to the recv expectation" do
      subject.receive_ringing foo: 'bar'

      scenario.to_xml.should match(%q{<recv foo="bar" response="180" optional="true"/>})
    end

    it "allows overriding options" do
      subject.receive_ringing optional: false

      scenario.to_xml.should match(%q{<recv optional="false" response="180"/>})
    end
  end

  describe '#receive_progress' do
    it "expects an optional 183" do
      subject.receive_progress

      scenario.to_xml.should match(%q{<recv response="183" optional="true"/>})
    end

    it "allows passing options to the recv expectation" do
      subject.receive_progress foo: 'bar'

      scenario.to_xml.should match(%q{<recv foo="bar" response="183" optional="true"/>})
    end

    it "allows overriding options" do
      subject.receive_progress optional: false

      scenario.to_xml.should match(%q{<recv optional="false" response="183"/>})
    end
  end

  describe '#receive_answer' do
    it "expects a 200 with rrs and rtd true" do
      subject.receive_answer

      scenario.to_xml.should match(%q{<recv response="200" rrs="true" rtd="true"/>})
    end

    it "allows passing options to the recv expectation" do
      subject.receive_answer foo: 'bar'

      scenario.to_xml.should match(%q{<recv response="200" rrs="true" rtd="true" foo="bar"/>})
    end

    it "allows overriding options" do
      subject.receive_answer rtd: false

      scenario.to_xml.should match(%q{<recv response="200" rrs="true" rtd="false"/>})
    end
  end

  describe '#receive_200' do
    it "expects a 200" do
      subject.receive_200

      scenario.to_xml.should match(%q{<recv response="200"/>})
    end

    it "allows passing options to the recv expectation" do
      subject.receive_200 foo: 'bar'

      scenario.to_xml.should match(%q{<recv response="200" foo="bar"/>})
    end

    it "allows overriding options" do
      subject.receive_200 response: 999 # Silly but still...

      scenario.to_xml.should match(%q{<recv response="999"/>})
    end
  end

  describe '#ack_answer' do
    it "sends an ACK message" do
      subject.ack_answer

      subject.to_xml.should match(%r{<send>})
      subject.to_xml.should match(%r{ACK})
    end

    it "allows setting options on the send instruction" do
      subject.ack_answer foo: 'bar'
      subject.to_xml.should match(%r{<send foo="bar".*>})
    end

    context "when media is present" do
      before do
        subject.answer
        subject.sleep 1
      end

      it "starts the PCAP media" do
        subject.ack_answer
        subject.sleep 1
        subject.to_xml(:pcap_path => "/dev/null").should match(%r{<nop>\n.*<action>\n.*<exec play_pcap_audio="/dev/null"/>\n.*</action>\n.*</nop>})
      end
    end

    context "when media is not present" do
      it "does not start the PCAP media" do
        subject.ack_answer
        subject.to_xml(:pcap_path => "/dev/null").should_not match(%r{<nop>\n.*<action>\n.*<exec play_pcap_audio="/dev/null"/>\n.*</action>\n.*</nop>})
      end
    end

    context "when a from user is specified" do
      let(:args) { {from_user: 'frank'} }

      it "includes the specified user in the From and Contact headers" do
        subject.ack_answer
        subject.to_xml.should match(%r{From: "frank" <sip:frank@})
        subject.to_xml.should match(%r{Contact: <sip:frank@})
      end
    end

    context "when no from user is specified" do
      it "uses a default of 'sipp' in the From and Contact headers" do
        subject.ack_answer
        subject.to_xml.should match(%r{From: "sipp" <sip:sipp@})
        subject.to_xml.should match(%r{Contact: <sip:sipp@})
      end
    end
  end

  describe '#wait_for_answer' do
    it "tells SIPp to optionally receive a SIP 100, 180 and 183 by default, while requiring a 200" do
      scenario.wait_for_answer

      xml = scenario.to_xml
      xml.should =~ /recv response="100".*optional="true"/
      xml.should =~ /recv response="180".*optional="true"/
      xml.should =~ /recv response="183".*optional="true"/
      xml.should =~ /recv response="200"/
      xml.should_not =~ /recv response="200".*optional="true"/
    end

    it "passes through additional options" do
      scenario.wait_for_answer foo: 'bar'

      xml = scenario.to_xml
      xml.should =~ /recv .*foo="bar".*response="100"/
      xml.should =~ /recv .*foo="bar".*response="180"/
      xml.should =~ /recv .*foo="bar".*response="183"/
      xml.should =~ /recv .*response="200" .*foo="bar"/
    end
  end

  describe '#receive_message' do
    it "expects a MESSAGE and acks it" do
      subject.receive_message
      subject.to_xml.should match(%r{<recv request="MESSAGE"/>.*SIP/2\.0 200 OK}m)
    end

    it "allows a string to be given as a regexp for matching" do
      subject.receive_message "Hello World!"
      subject.to_xml.should match(%r{<action>\s*<ereg regexp="Hello World!" search_in="body" check_it="true" assign_to="[^"]+"/>\s*</action>}m)
    end

    it "increments the variable name used for regexp matching because SIPp requires it to be unique" do
      subject.receive_message "Hello World!"
      subject.receive_message "Hello Again World!"
      subject.receive_message "Goodbye World!"
      subject.to_xml.should match(%r{<ereg [^>]* assign_to="([^"]+)_1"/>.*<ereg [^>]* assign_to="\1_2"/>.*<ereg [^>]* assign_to="\1_3"/>}m)
    end

    it "declares the variable used for regexp matching so that SIPp doesn't complain that it's unused" do
      subject.receive_message "Hello World!"
      subject.to_xml.should match(%r{<ereg [^>]* assign_to="([^"]+)"/>.*<Reference variables="\1"/>}m)
    end
  end

  describe '#send_bye' do
    it "sends a BYE message" do
      subject.send_bye

      subject.to_xml.should match(%r{<send>})
      subject.to_xml.should match(%r{BYE})
    end

    it "allows setting options on the send instruction" do
      subject.send_bye foo: 'bar'
      subject.to_xml.should match(%r{<send foo="bar".*>})
    end

    it "uses a default of 'sipp' in the From and Contact headers" do
      subject.send_bye
      subject.to_xml.should match(%r{From: \[\$invite_to\];tag=\[call_number\]})
      subject.to_xml.should match(%r{Contact: \[\$invite_contact\]})
    end
  end

  describe '#receive_bye' do
    it "expects a BYE" do
      subject.receive_bye

      scenario.to_xml.should match(%q{<recv request="BYE"/>})
    end

    it "allows passing options to the recv expectation" do
      subject.receive_bye foo: 'bar'

      scenario.to_xml.should match(%q{<recv foo="bar" request="BYE"/>})
    end
  end

  describe '#okay' do
    it "sends a 200 OK" do
      subject.okay

      subject.to_xml.should match(%r{<send>})
      subject.to_xml.should match(%r{SIP/2.0 200 OK})
    end

    it "allows setting options on the send instruction" do
      subject.okay foo: 'bar'
      subject.to_xml.should match(%r{<send foo="bar".*>})
    end

    context "when a from user is specified" do
      let(:args) { {from_user: 'frank'} }

      it "includes the specified user in the Contact header" do
        subject.okay
        subject.to_xml.should match(%r{Contact: <sip:frank@})
      end
    end

    context "when no from user is specified" do
      it "uses a default of 'sipp' in the Contact header" do
        subject.okay
        subject.to_xml.should match(%r{Contact: <sip:sipp@})
      end
    end
  end

  describe '#wait_for_hangup' do
    it "expects a BYE and acks it" do
      subject.receive_bye foo: 'bar'

      scenario.to_xml.should match(%q{<recv foo="bar" request="BYE"/>})
      scenario.to_xml.should match(%q{<recv foo="bar" request="BYE"/>})
    end
  end

  describe 'media-dependent operations' do
    let(:media) { double :media }
    before do
      SippyCup::Media.should_receive(:new).once.and_return media
      scenario.ack_answer
      media.stub :<<
    end

    describe '#sleep' do
      it "creates the proper amount of silent audio'" do
        media.should_receive(:<<).once.with 'silence:5000'
        scenario.sleep 5
      end

      it "should insert a pause into the scenario" do
        scenario.sleep 5
        scenario.to_xml.should match(%r{<pause milliseconds="5000"/>})
      end

      context "when passed fractional seconds" do
        it "creates the proper amount of silent audio" do
          media.should_receive(:<<).once.with 'silence:500'
          scenario.sleep '0.5'
        end

        it "should insert a pause into the scenario" do
          scenario.sleep 0.5
          scenario.to_xml.should match(%r{<pause milliseconds="500"/>})
        end
      end
    end

    describe '#send_digits' do
      it "creates the requested DTMF string in media, with 250ms pauses between" do
        media.should_receive(:<<).ordered.with 'dtmf:1'
        media.should_receive(:<<).ordered.with 'silence:250'
        media.should_receive(:<<).ordered.with 'dtmf:3'
        media.should_receive(:<<).ordered.with 'silence:250'
        media.should_receive(:<<).ordered.with 'dtmf:6'
        media.should_receive(:<<).ordered.with 'silence:250'
        scenario.send_digits '136'
      end

      it "should insert a pause into the scenario to cover the DTMF duration (250ms) and the pause" do
        scenario.send_digits '136'
        scenario.to_xml.should match(%r{<pause milliseconds="1500"/>})
      end
    end
  end

  describe "#send_digits with a SIP INFO DTMF mode" do
    let(:args) { {dtmf_mode: 'info'} }
    before { scenario.answer }

    it "creates the requested DTMF string as SIP INFO messages" do
      scenario.send_digits '136'

      xml = scenario.to_xml
      scenario.to_xml.should match(%r{(<send>.*INFO \[next_url\] SIP/2\.0.*</send>.*){3}}m)
      scenario.to_xml.should match(%r{Signal=1(\nDuration=250\n).*Signal=3\1.*Signal=6\1}m)
    end

    it "expects a response for each digit sent" do
      scenario.send_digits '123'
      scenario.to_xml.should match(%r{(<send>.*INFO.*</send>.*<recv response="200"/>.*){3}}m)
    end

    it "inserts 250ms pauses between each digit" do
      scenario.send_digits '321'
      scenario.to_xml.should match(%r{(<send>.*INFO.*</send>.*<pause milliseconds="250"/>.*){3}}m)
    end
  end

  describe "#compile!" do
    context "when a filename is not provided" do
      it "writes the scenario XML to disk at name.xml" do
        scenario.invite

        scenario.compile!

        File.read("/tmp/test.xml").should == scenario.to_xml
      end

      it "writes the PCAP media to disk at name.pcap" do
        scenario.ack_answer
        scenario.send_digits '123'

        scenario.compile!

        File.read("/tmp/test.pcap").should_not be_empty
      end

      it "returns the path to the scenario file" do
        scenario.compile!.should == "/tmp/test.xml"
      end
    end

    context "when a filename is provided" do
      let(:args) { {filename: 'foobar'} }

      it "writes the scenario XML to disk at filename.xml" do
        scenario.invite

        scenario.compile!

        File.read("/tmp/foobar.xml").should == scenario.to_xml
      end

      it "writes the PCAP media to disk at filename.pcap" do
        scenario.ack_answer
        scenario.send_digits '123'

        scenario.compile!

        File.read("/tmp/foobar.pcap").should_not be_empty
      end

      it "returns the path to the scenario file" do
        scenario.compile!.should == "/tmp/foobar.xml"
      end
    end
  end

  describe "#to_tmpfiles" do
    before { scenario.invite }

    it "writes the scenario XML to a Tempfile and returns it" do
      files = scenario.to_tmpfiles
      files[:scenario].should be_a(Tempfile)
      files[:scenario].read.should eql(scenario.to_xml)
    end

    it "allows the scenario XML to be read from disk independently" do
      files = scenario.to_tmpfiles
      File.read(files[:scenario].path).should eql(scenario.to_xml)
    end

    context "without media" do
      it "does not write a PCAP media file" do
        files = scenario.to_tmpfiles
        files[:media].should be_nil
      end
    end

    context "with media" do
      before do
        scenario.ack_answer
        scenario.sleep 1
      end

      it "writes the PCAP media to a Tempfile and returns it" do
        files = scenario.to_tmpfiles
        files[:media].should be_a(Tempfile)
        files[:media].read.should_not be_empty
      end

      it "allows the PCAP media to be read from disk independently" do
        files = scenario.to_tmpfiles
        File.read(files[:media].path).should_not be_empty
      end

      it "puts the PCAP file path into the scenario XML" do
        files = scenario.to_tmpfiles
        files[:scenario].read.should match(%r{play_pcap_audio="#{files[:media].path}"})
      end
    end
  end

  describe "#build" do
    let(:scenario_xml) do <<-END
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
<action><assignstr assign_to="invite_to" value="[service]@[remote_ip]:[remote_port]"/><assignstr assign_to="invite_from" value="sipp@[local_ip]"/><assignstr assign_to="invite_contact" value="sipp@[local_ip]:[local_port];transport=[transport]"/></action></send>
  <recv response="100" optional="true"/>
  <recv response="180" optional="true"/>
  <recv response="183" optional="true"/>
  <recv response="200" rrs="true" rtd="true"/>
  <send>
<![CDATA[
ACK [next_url] SIP/2.0
Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
From: "sipp" <sip:sipp@[local_ip]>;tag=[call_number]
To: <sip:[service]@[remote_ip]:[remote_port]>[peer_tag_param]
Call-ID: [call_id]
CSeq: [cseq] ACK
Contact: <sip:sipp@[local_ip]:[local_port];transport=[transport]>
Max-Forwards: 100
User-Agent: SIPp/sippy_cup
Content-Length: 0
[routes]
]]>
</send>
  <recv request="BYE"/>
  <send>
<![CDATA[
SIP/2.0 200 OK
[last_Via:]
[last_From:]
[last_To:]
[last_Call-ID:]
[last_CSeq:]
Contact: <sip:sipp@[local_ip]:[local_port];transport=[transport]>
Max-Forwards: 100
User-Agent: SIPp/sippy_cup
Content-Length: 0
[routes]
]]>
</send>
</scenario>
    END
    end

    context "with a valid steps definition" do
      let(:steps) { ['invite', 'wait_for_answer', 'ack_answer', 'wait_for_hangup'] }

      it "runs each step" do
        subject.build(steps)
        subject.to_xml(:pcap_path => "/dev/null").should == scenario_xml
      end
    end

    context "having steps with arguments" do
      let(:steps) do
        [
          %q(register 'user@domain.com' "my password has spaces"),
          %q(sleep 3),
          %q(send_digits 12345)
        ]
      end

      it "each method should receive the correct arguments" do
        subject.should_receive(:register).once.ordered.with('user@domain.com', 'my password has spaces')
        subject.should_receive(:sleep).once.ordered.with('3')
        subject.should_receive(:send_digits).once.ordered.with('12345')
        subject.build steps
      end
    end

    context "with an invalid steps definition" do
      let(:steps) { ["send_digits 'b'"] }

      it "doesn't raise errors" do
        expect { subject.build(steps) }.to_not raise_error
      end
    end
  end

  describe ".from_manifest" do
    let(:specs_from) { 'specs' }

    let(:scenario_yaml) do <<-END
name: spec scenario
source: 192.0.2.15
destination: 192.0.2.200
max_concurrent: 10
calls_per_second: 5
number_of_calls: 20
from_user: #{specs_from}
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits '3125551234'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
      END
    end

    let(:scenario_xml) do <<-END
<?xml version="1.0"?>
<scenario name="spec scenario">
  <send retrans="500">
<![CDATA[
INVITE sip:[service]@[remote_ip]:[remote_port] SIP/2.0
Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
From: "#{specs_from}" <sip:#{specs_from}@[local_ip]>;tag=[call_number]
To: <sip:[service]@[remote_ip]:[remote_port]>
Call-ID: [call_id]
CSeq: [cseq] INVITE
Contact: <sip:#{specs_from}@[local_ip]:[local_port];transport=[transport]>
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
<action><assignstr assign_to="invite_to" value="[service]@[remote_ip]:[remote_port]"/><assignstr assign_to="invite_from" value="#{specs_from}@[local_ip]"/><assignstr assign_to="invite_contact" value="#{specs_from}@[local_ip]:[local_port];transport=[transport]"/></action></send>
  <recv response="100" optional="true"/>
  <recv response="180" optional="true"/>
  <recv response="183" optional="true"/>
  <recv response="200" rrs="true" rtd="true"/>
  <send>
<![CDATA[
ACK [next_url] SIP/2.0
Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
From: "#{specs_from}" <sip:#{specs_from}@[local_ip]>;tag=[call_number]
To: <sip:[service]@[remote_ip]:[remote_port]>[peer_tag_param]
Call-ID: [call_id]
CSeq: [cseq] ACK
Contact: <sip:#{specs_from}@[local_ip]:[local_port];transport=[transport]>
Max-Forwards: 100
User-Agent: SIPp/sippy_cup
Content-Length: 0
[routes]
]]>
</send>
  <nop>
    <action>
      <exec play_pcap_audio="/dev/null"/>
    </action>
  </nop>
  <pause milliseconds="3000"/>
  <pause milliseconds="5000"/>
  <pause milliseconds="5000"/>
  <pause milliseconds="500"/>
  <recv request="BYE"/>
  <send>
<![CDATA[
SIP/2.0 200 OK
[last_Via:]
[last_From:]
[last_To:]
[last_Call-ID:]
[last_CSeq:]
Contact: <sip:#{specs_from}@[local_ip]:[local_port];transport=[transport]>
Max-Forwards: 100
User-Agent: SIPp/sippy_cup
Content-Length: 0
[routes]
]]>
</send>
</scenario>
      END
    end

    let(:override_options) { { number_of_calls: 10 } }

    it "generates the correct XML" do
      scenario = described_class.from_manifest(scenario_yaml)
      scenario.to_xml(:pcap_path => "/dev/null").should == scenario_xml
    end

    it "sets the proper options" do
      scenario = described_class.from_manifest(scenario_yaml)
      scenario.scenario_options.should == {
        'name' => 'spec scenario',
        'source' => '192.0.2.15',
        'destination' => '192.0.2.200',
        'max_concurrent' => 10,
        'calls_per_second' => 5,
        'number_of_calls' => 20,
        'from_user' => "#{specs_from}"
      }
    end

    context "when the :scenario key is provided in the manifest" do
      let(:scenario_path) { File.expand_path('scenario.xml', File.join(File.dirname(__FILE__), '..', 'fixtures')) }
      let(:scenario_yaml) do <<-END
name: spec scenario
source: 192.0.2.15
destination: 192.0.2.200
max_concurrent: 10
calls_per_second: 5
number_of_calls: 20
from_user: #{specs_from}
scenario: #{scenario_path}
        END
      end

      before { FakeFS.deactivate! }

      it "creates an XMLScenario with the scenario XML and nil media" do
        scenario = described_class.from_manifest(scenario_yaml)
        scenario.should be_a(SippyCup::XMLScenario)
        scenario.to_xml.should == File.read(scenario_path)
      end

      context "and the :media key is provided" do
        let(:media_path) { File.expand_path('dtmf_2833_1.pcap', File.join(File.dirname(__FILE__), '..', 'fixtures')) }
        let(:scenario_yaml) do <<-END
name: spec scenario
source: 192.0.2.15
destination: 192.0.2.200
max_concurrent: 10
calls_per_second: 5
number_of_calls: 20
from_user: #{specs_from}
scenario: #{scenario_path}
media: #{media_path}
          END
        end

        it "creates an XMLScenario with the scenario XML and media from the filesystem" do
          scenario = described_class.from_manifest(scenario_yaml)

          media = File.read(media_path, mode: 'rb')

          files = scenario.to_tmpfiles
          files[:media].read.should eql(media)
        end
      end
    end

    context "without a name specified" do
      let(:scenario_yaml) do <<-END
source: 192.0.2.15
destination: 192.0.2.200
max_concurrent: 10
calls_per_second: 5
number_of_calls: 20
from_user: #{specs_from}
steps:
- invite
- wait_for_answer
- ack_answer
- sleep 3
- send_digits '3125551234'
- sleep 5
- send_digits '#'
- wait_for_hangup
        END
      end

      it "should default to 'My Scenario'" do
        scenario = described_class.from_manifest(scenario_yaml)
        scenario.scenario_options[:name].should == 'My Scenario'
      end
    end

    context "with an input filename specified" do
      context "and a name in the manifest" do
        it "uses the name from the manifest" do
          scenario = described_class.from_manifest(scenario_yaml, input_filename: '/tmp/foobar.yml')
          scenario.scenario_options[:name].should == 'spec scenario'
        end
      end

      context "and no name in the manifest" do
        let(:scenario_yaml) do <<-END
source: 192.0.2.15
destination: 192.0.2.200
max_concurrent: 10
calls_per_second: 5
number_of_calls: 20
from_user: #{specs_from}
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits '3125551234'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
          END
        end

        it "uses the input filename" do
          scenario = described_class.from_manifest(scenario_yaml, input_filename: '/tmp/foobar.yml')
          scenario.scenario_options[:name].should == 'foobar'
        end
      end
    end

    context "overriding some value" do
      let(:specs_from) { 'other_user' }

      it "overrides keys with values from the options hash" do
        scenario = described_class.from_manifest(scenario_yaml, override_options)
        scenario.to_xml(:pcap_path => "/dev/null").should == scenario_xml
      end

      it "sets the proper options" do
        scenario = described_class.from_manifest(scenario_yaml, override_options)
        scenario.scenario_options.should == {
          'name' => 'spec scenario',
          'source' => '192.0.2.15',
          'destination' => '192.0.2.200',
          'max_concurrent' => 10,
          'calls_per_second' => 5,
          'number_of_calls' => override_options[:number_of_calls],
          'from_user' => "#{specs_from}"
        }
      end
    end

    context "with an invalid scenario" do
      let(:scenario_yaml) do <<-END
name: spec scenario
source: 192.0.2.15
destination: 192.0.2.200
max_concurrent: 10
calls_per_second: 5
number_of_calls: 20
from_user: #{specs_from}
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits 'abc'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
      END
      end

      it "does not raise errors" do
        expect { SippyCup::Scenario.from_manifest(scenario_yaml) }.to_not raise_error
      end

      it "sets the validity of the scenario" do
        scenario = SippyCup::Scenario.from_manifest(scenario_yaml)
        scenario.should_not be_valid
      end

      it "sets the error messages for the scenario" do
        scenario = SippyCup::Scenario.from_manifest(scenario_yaml)
        scenario.errors.should == [{step: 5, message: "send_digits 'abc': Invalid DTMF digit requested: a"}]
      end
    end
  end
end
