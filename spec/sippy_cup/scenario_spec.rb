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

    expect(s.to_xml).to match(%r{INVITE sip:\[service\]@\[remote_ip\]:\[remote_port\] SIP/2.0})
  end

  it "allows creating a blank scenario with no block" do
    expect(subject.to_xml).to match(%r{<scenario name="Test"/>})
  end

  describe '#invite' do
    it "sends an INVITE message" do
      subject.invite

      expect(subject.to_xml).to match(%r{<send .*>})
      expect(subject.to_xml).to match(%r{INVITE})
    end

    it "allows setting options on the send instruction" do
      subject.invite foo: 'bar'

      expect(subject.to_xml).to match(%r{<send foo="bar".*>})
    end

    it "defaults to retrans of 500" do
      subject.invite
      expect(subject.to_xml).to match(%r{<send retrans="500".*>})
    end

    it "allows setting retrans" do
      subject.invite retrans: 200
      expect(subject.to_xml).to match(%r{<send retrans="200".*>})
    end

    context "with extra headers specified" do
      it "adds the headers to the end of the message" do
        subject.invite headers: "Foo: <bar>\nBar: <baz>"
        expect(subject.to_xml).to match(%r{Foo: <bar>\nBar: <baz>})
      end

      it "only has one blank line between headers and SDP" do
        subject.invite headers: "Foo: <bar>\n\n\n"
        expect(subject.to_xml).to match(%r{Foo: <bar>\n\nv=0})
      end
    end

    context "with no extra headers" do
      it "only has one blank line between headers and SDP" do
        subject.invite
        expect(subject.to_xml).to match(%r{Content-Length: \[len\]\n\nv=0})
      end
    end

    it "uses [media_port+1] as the RTCP port in the SDP" do
      subject.invite
      expect(subject.to_xml).to match(%r{m=audio \[media_port\] RTP/AVP 0 101\n})
    end

    context "when a from user is specified" do
      let(:args) { {from_user: 'frank'} }

      it "includes the specified user in the From and Contact headers" do
        subject.invite
        expect(subject.to_xml).to match(%r{From: "frank" <sip:frank@})
        expect(subject.to_xml).to match(%r{Contact: <sip:frank@})
      end
    end

    context "when no from user is specified" do
      it "uses a default of 'sipp' in the From and Contact headers" do
        subject.invite
        expect(subject.to_xml).to match(%r{From: "sipp" <sip:sipp@})
        expect(subject.to_xml).to match(%r{Contact: <sip:sipp@})
      end
    end

    context "when a to user is specified" do
      let(:args) { {to: 'usera'} }

      it "includes the specified user in the To header and URI line" do
        subject.invite
        expect(subject.to_xml).to match(%r{To: <sip:\[service\]@\[remote_ip\]:\[remote_port\]})
        expect(subject.to_xml).to match(%r{INVITE sip:\[service\]@\[remote_ip\]:\[remote_port\]})
      end
    end

    context "when a to address is specified" do
      let(:args) { {to: 'usera@foo.bar'} }

      it "includes the specified address in the To header and URI line" do
        subject.invite
        expect(subject.to_xml).to match(%r{To: <sip:\[service\]@foo.bar:\[remote_port\]})
        expect(subject.to_xml).to match(%r{INVITE sip:\[service\]@foo.bar:\[remote_port\]})
      end
    end

    context "when no to is specified" do
      it "uses a default of '[remote_ip]' in the To header and URI line" do
        subject.invite
        expect(subject.to_xml).to match(%r{To: <sip:\[service\]@\[remote_ip\]:\[remote_port\]})
        expect(subject.to_xml).to match(%r{INVITE sip:\[service\]@\[remote_ip\]:\[remote_port\]})
      end
    end
  end

  describe "#register" do
    it "sends a REGISTER message" do
      subject.register 'frank'

      expect(subject.to_xml).to match(%r{<send.*>})
      expect(subject.to_xml).to match(%r{REGISTER})
    end

    it "allows setting options on the send instruction" do
      subject.register 'frank', nil, foo: 'bar'
      expect(subject.to_xml).to match(%r{<send foo="bar".*>})
    end

    it "defaults to retrans of 500" do
      subject.register 'frank'
      expect(subject.to_xml).to match(%r{<send retrans="500".*>})
    end

    it "allows setting retrans" do
      subject.register 'frank', nil, retrans: 200
      expect(subject.to_xml).to match(%r{<send retrans="200".*>})
    end

    context "when a domain is provided" do
      it "uses the specified user and domain" do
        subject.register 'frank@foobar.com'
        expect(subject.to_xml).to match(%r{REGISTER sip:foobar.com})
        expect(subject.to_xml).to match(%r{From: <sip:frank@foobar.com})
        expect(subject.to_xml).to match(%r{To: <sip:frank@foobar.com})
        expect(subject.to_xml).to match(%r{Contact: <sip:sipp@\[local_ip\]})
      end
    end

    context "when a domain is not provided" do
      it "uses the remote IP" do
        subject.register 'frank'
        expect(subject.to_xml).to match(%r{REGISTER sip:\[remote_ip\]})
        expect(subject.to_xml).to match(%r{From: <sip:frank@\[remote_ip\]})
        expect(subject.to_xml).to match(%r{To: <sip:frank@\[remote_ip\]})
        expect(subject.to_xml).to match(%r{Contact: <sip:sipp@\[local_ip\]})
      end
    end

    context "when a password is provided" do
      it "expects a 401 response" do
        pending "Need to check for initial request, then 401, then retry with authentication"
        subject.register 'frank', 'abc123'
        expect(subject.to_xml).to match(%r{<recv response="401" auth="true" optional="false"/>})
        fail "Not yet implemented"
      end

      it "adds authentication data to the REGISTER message" do
        subject.register 'frank', 'abc123'
        expect(subject.to_xml).to match(%r{\[authentication username=frank password=abc123\]})
      end
    end
  end

  describe '#receive_trying' do
    it "expects an optional 100" do
      subject.receive_trying

      expect(scenario.to_xml).to match(%q{<recv response="100" optional="true"/>})
    end

    it "allows passing options to the recv expectation" do
      subject.receive_trying foo: 'bar'

      expect(scenario.to_xml).to match(%q{<recv foo="bar" response="100" optional="true"/>})
    end

    it "allows overriding options" do
      subject.receive_trying optional: false

      expect(scenario.to_xml).to match(%q{<recv optional="false" response="100"/>})
    end
  end

  describe '#receive_ringing' do
    it "expects an optional 180" do
      subject.receive_ringing

      expect(scenario.to_xml).to match(%q{<recv response="180" optional="true"/>})
    end

    it "allows passing options to the recv expectation" do
      subject.receive_ringing foo: 'bar'

      expect(scenario.to_xml).to match(%q{<recv foo="bar" response="180" optional="true"/>})
    end

    it "allows overriding options" do
      subject.receive_ringing optional: false

      expect(scenario.to_xml).to match(%q{<recv optional="false" response="180"/>})
    end
  end

  describe '#receive_progress' do
    it "expects an optional 183" do
      subject.receive_progress

      expect(scenario.to_xml).to match(%q{<recv response="183" optional="true"/>})
    end

    it "allows passing options to the recv expectation" do
      subject.receive_progress foo: 'bar'

      expect(scenario.to_xml).to match(%q{<recv foo="bar" response="183" optional="true"/>})
    end

    it "allows overriding options" do
      subject.receive_progress optional: false

      expect(scenario.to_xml).to match(%q{<recv optional="false" response="183"/>})
    end
  end

  describe '#receive_answer' do
    it "expects a 200 with rrs and rtd true" do
      subject.receive_answer

      expect(scenario.to_xml).to match(%q{<recv response="200" rrs="true" rtd="true">})
    end

    it "allows passing options to the recv expectation" do
      subject.receive_answer foo: 'bar'

      expect(scenario.to_xml).to match(%q{<recv response="200" rrs="true" rtd="true" foo="bar">})
    end

    it "allows overriding options" do
      subject.receive_answer rtd: false

      expect(scenario.to_xml).to match(%q{<recv response="200" rrs="true" rtd="false">})
    end
  end

  describe '#receive_200' do
    it "expects a 200" do
      subject.receive_200

      expect(scenario.to_xml).to match(%q{<recv response="200"/>})
    end

    it "allows passing options to the recv expectation" do
      subject.receive_200 foo: 'bar'

      expect(scenario.to_xml).to match(%q{<recv response="200" foo="bar"/>})
    end

    it "allows overriding options" do
      subject.receive_200 response: 999 # Silly but still...

      expect(scenario.to_xml).to match(%q{<recv response="999"/>})
    end
  end

  describe '#ack_answer' do
    it "sends an ACK message" do
      subject.ack_answer

      expect(subject.to_xml).to match(%r{<send>})
      expect(subject.to_xml).to match(%r{ACK})
    end

    it "allows setting options on the send instruction" do
      subject.ack_answer foo: 'bar'
      expect(subject.to_xml).to match(%r{<send foo="bar".*>})
    end

    context "when media is present" do
      before do
        subject.answer
        subject.sleep 1
      end

      it "starts the PCAP media" do
        subject.ack_answer
        subject.sleep 1
        expect(subject.to_xml(:pcap_path => "/dev/null")).to match(%r{<nop>\n.*<action>\n.*<exec play_pcap_audio="/dev/null"/>\n.*</action>\n.*</nop>})
      end
    end

    context "when media is not present" do
      it "does not start the PCAP media" do
        subject.ack_answer
        expect(subject.to_xml(:pcap_path => "/dev/null")).not_to match(%r{<nop>\n.*<action>\n.*<exec play_pcap_audio="/dev/null"/>\n.*</action>\n.*</nop>})
      end
    end
  end

  describe '#wait_for_answer' do
    it "tells SIPp to optionally receive a SIP 100, 180 and 183 by default, while requiring a 200" do
      scenario.wait_for_answer

      xml = scenario.to_xml
      expect(xml).to match(/recv response="100".*optional="true"/)
      expect(xml).to match(/recv response="180".*optional="true"/)
      expect(xml).to match(/recv response="183".*optional="true"/)
      expect(xml).to match(/recv response="200"/)
      expect(xml).not_to match(/recv response="200".*optional="true"/)
      expect(xml).to match(%r{<send>})
      expect(xml).to match(%r{ACK})
    end

    it "passes through additional options" do
      scenario.wait_for_answer foo: 'bar'

      xml = scenario.to_xml
      expect(xml).to match(/recv .*foo="bar".*response="100"/)
      expect(xml).to match(/recv .*foo="bar".*response="180"/)
      expect(xml).to match(/recv .*foo="bar".*response="183"/)
      expect(xml).to match(/recv .*response="200" .*foo="bar"/)
      expect(xml).to match(%r{<send.*foo="bar".*>})
      expect(xml).to match(%r{ACK})
    end
  end

  describe '#receive_message' do
    it "expects a MESSAGE and acks it" do
      subject.receive_message
      expect(subject.to_xml).to match(%r{<recv request="MESSAGE"/>.*SIP/2\.0 200 OK}m)
    end

    it "allows a string to be given as a regexp for matching" do
      subject.receive_message "Hello World!"
      expect(subject.to_xml).to match(%r{<action>\s*<ereg regexp="Hello World!" search_in="body" check_it="true" assign_to="[^"]+"/>\s*</action>}m)
    end

    it "increments the variable name used for regexp matching because SIPp requires it to be unique" do
      subject.receive_message "Hello World!"
      subject.receive_message "Hello Again World!"
      subject.receive_message "Goodbye World!"
      expect(subject.to_xml).to match(%r{<ereg [^>]* assign_to="([^"]+)_1"/>.*<ereg [^>]* assign_to="\1_2"/>.*<ereg [^>]* assign_to="\1_3"/>}m)
    end

    it "declares the variable used for regexp matching so that SIPp doesn't complain that it's unused" do
      subject.receive_message "Hello World!"
      expect(subject.to_xml).to match(%r{<ereg [^>]* assign_to="([^"]+)"/>.*<Reference variables="\1"/>}m)
    end
  end

  describe '#send_bye' do
    it "sends a BYE message" do
      subject.send_bye

      expect(subject.to_xml).to match(%r{<send>})
      expect(subject.to_xml).to match(%r{BYE})
    end

    it "allows setting options on the send instruction" do
      subject.send_bye foo: 'bar'
      expect(subject.to_xml).to match(%r{<send foo="bar".*>})
    end
  end

  describe '#receive_bye' do
    it "expects a BYE" do
      subject.receive_bye

      expect(scenario.to_xml).to match(%q{<recv request="BYE"/>})
    end

    it "allows passing options to the recv expectation" do
      subject.receive_bye foo: 'bar'

      expect(scenario.to_xml).to match(%q{<recv foo="bar" request="BYE"/>})
    end
  end

  describe '#okay' do
    it "sends a 200 OK" do
      subject.okay

      expect(subject.to_xml).to match(%r{<send>})
      expect(subject.to_xml).to match(%r{SIP/2.0 200 OK})
    end

    it "allows setting options on the send instruction" do
      subject.okay foo: 'bar'
      expect(subject.to_xml).to match(%r{<send foo="bar".*>})
    end
  end

  describe '#wait_for_hangup' do
    it "expects a BYE and acks it" do
      subject.receive_bye foo: 'bar'

      expect(scenario.to_xml).to match(%q{<recv foo="bar" request="BYE"/>})
      expect(scenario.to_xml).to match(%q{<recv foo="bar" request="BYE"/>})
    end
  end

  describe '#call_length_repartition' do
    it 'create a partition table' do
      subject.call_length_repartition('1', '10', '2')
      expect(scenario.to_xml).to match('<CallLengthRepartition value="1,3,5,7,9"/>')
    end
  end

  describe '#response_time_repartition' do
    it 'create a partition table' do
      subject.response_time_repartition('1', '10', '2')
      expect(scenario.to_xml).to match('<ResponseTimeRepartition value="1,3,5,7,9"/>')
    end
  end

  describe 'media-dependent operations' do
    let(:media) { double :media }
    before do
      expect(SippyCup::Media).to receive(:new).once.and_return media
      scenario.ack_answer
      allow(media).to receive :<<
    end

    describe '#sleep' do
      it "creates the proper amount of silent audio'" do
        expect(media).to receive(:<<).once.with 'silence:5000'
        scenario.sleep 5
      end

      it "should insert a pause into the scenario" do
        scenario.sleep 5
        expect(scenario.to_xml).to match(%r{<pause milliseconds="5000"/>})
      end

      context "when passed fractional seconds" do
        it "creates the proper amount of silent audio" do
          expect(media).to receive(:<<).once.with 'silence:500'
          scenario.sleep '0.5'
        end

        it "should insert a pause into the scenario" do
          scenario.sleep 0.5
          expect(scenario.to_xml).to match(%r{<pause milliseconds="500"/>})
        end
      end
    end

    describe '#send_digits' do
      it "creates the requested DTMF string in media, with 250ms pauses between" do
        expect(media).to receive(:<<).ordered.with 'dtmf:1'
        expect(media).to receive(:<<).ordered.with 'silence:250'
        expect(media).to receive(:<<).ordered.with 'dtmf:3'
        expect(media).to receive(:<<).ordered.with 'silence:250'
        expect(media).to receive(:<<).ordered.with 'dtmf:6'
        expect(media).to receive(:<<).ordered.with 'silence:250'
        scenario.send_digits '136'
      end

      it "should insert a pause into the scenario to cover the DTMF duration (250ms) and the pause" do
        scenario.send_digits '136'
        expect(scenario.to_xml).to match(%r{<pause milliseconds="1500"/>})
      end
    end
  end

  describe "#send_digits with a SIP INFO DTMF mode" do
    let(:args) { {dtmf_mode: 'info'} }
    before { scenario.answer }

    it "creates the requested DTMF string as SIP INFO messages" do
      scenario.send_digits '136'

      xml = scenario.to_xml
      expect(scenario.to_xml).to match(%r{(<send>.*INFO \[next_url\] SIP/2\.0.*</send>.*){3}}m)
      expect(scenario.to_xml).to match(%r{Signal=1(\nDuration=250\n).*Signal=3\1.*Signal=6\1}m)
    end

    it "expects a response for each digit sent" do
      scenario.send_digits '123'
      expect(scenario.to_xml).to match(%r{(<send>.*INFO.*</send>.*<recv response="200"/>.*){3}}m)
    end

    it "inserts 250ms pauses between each digit" do
      scenario.send_digits '321'
      expect(scenario.to_xml).to match(%r{(<send>.*INFO.*</send>.*<pause milliseconds="250"/>.*){3}}m)
    end
  end

  describe "#compile!" do
    context "when a filename is not provided" do
      it "writes the scenario XML to disk at name.xml" do
        scenario.invite

        scenario.compile!

        expect(File.read("/tmp/test.xml")).to eq(scenario.to_xml)
      end

      it "writes the PCAP media to disk at name.pcap" do
        scenario.ack_answer
        scenario.send_digits '123'

        scenario.compile!

        expect(File.read("/tmp/test.pcap")).not_to be_empty
      end

      it "returns the path to the scenario file" do
        expect(scenario.compile!).to eq("/tmp/test.xml")
      end
    end

    context "when a filename is provided" do
      let(:args) { {filename: 'foobar'} }

      it "writes the scenario XML to disk at filename.xml" do
        scenario.invite

        scenario.compile!

        expect(File.read("/tmp/foobar.xml")).to eq(scenario.to_xml)
      end

      it "writes the PCAP media to disk at filename.pcap" do
        scenario.ack_answer
        scenario.send_digits '123'

        scenario.compile!

        expect(File.read("/tmp/foobar.pcap")).not_to be_empty
      end

      it "returns the path to the scenario file" do
        expect(scenario.compile!).to eq("/tmp/foobar.xml")
      end
    end
  end

  describe "#to_tmpfiles" do
    before { scenario.invite }

    it "writes the scenario XML to a Tempfile and returns it" do
      files = scenario.to_tmpfiles
      expect(files[:scenario]).to be_a(Tempfile)
      expect(files[:scenario].read).to eql(scenario.to_xml)
    end

    it "allows the scenario XML to be read from disk independently" do
      files = scenario.to_tmpfiles
      expect(File.read(files[:scenario].path)).to eql(scenario.to_xml)
    end

    context "without media" do
      it "does not write a PCAP media file" do
        files = scenario.to_tmpfiles
        expect(files[:media]).to be_nil
      end
    end

    context "with media" do
      before do
        scenario.ack_answer
        scenario.sleep 1
      end

      it "writes the PCAP media to a Tempfile and returns it" do
        files = scenario.to_tmpfiles
        expect(files[:media]).to be_a(Tempfile)
        expect(files[:media].read).not_to be_empty
      end

      it "allows the PCAP media to be read from disk independently" do
        files = scenario.to_tmpfiles
        expect(File.read(files[:media].path)).not_to be_empty
      end

      it "puts the PCAP file path into the scenario XML" do
        files = scenario.to_tmpfiles
        expect(files[:scenario].read).to match(%r{play_pcap_audio="#{files[:media].path}"})
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
From: "sipp" <sip:sipp@[local_ip]:[local_port]>;tag=[call_number]
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
<action><assignstr assign_to="remote_addr" value="[service]@[remote_ip]:[remote_port]"/><assignstr assign_to="local_addr" value="sipp@[local_ip]:[local_port]"/><assignstr assign_to="call_addr" value="[service]@[remote_ip]:[remote_port]"/></action></send>
  <recv response="100" optional="true"/>
  <recv response="180" optional="true"/>
  <recv response="183" optional="true"/>
  <recv response="200" rrs="true" rtd="true">
    <action>
      <ereg regexp="&lt;sip:(.*)&gt;.*;tag=([^;]*)" search_in="hdr" header="To:" assign_to="dummy,remote_addr,remote_tag"/>
    </action>
  </recv>
  <send>
<![CDATA[
ACK [next_url] SIP/2.0
Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
From: "sipp" <sip:sipp@[local_ip]:[local_port]>;tag=[call_number]
To: <sip:[service]@[remote_ip]:[remote_port]>[peer_tag_param]
Call-ID: [call_id]
CSeq: [cseq] ACK
Contact: <sip:[$local_addr];transport=[transport]>
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
Contact: <sip:[$local_addr];transport=[transport]>
Max-Forwards: 100
User-Agent: SIPp/sippy_cup
Content-Length: 0
[routes]
]]>
</send>
  <Reference variables="remote_addr,local_addr,call_addr,dummy,remote_tag"/>
</scenario>
    END
    end

    context "with a valid steps definition" do
      let(:steps) { ['invite', 'wait_for_answer', 'wait_for_hangup'] }

      it "runs each step" do
        subject.build(steps)
        expect(subject.to_xml(:pcap_path => "/dev/null")).to eq(scenario_xml)
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
        expect(subject).to receive(:register).once.ordered.with('user@domain.com', 'my password has spaces')
        expect(subject).to receive(:sleep).once.ordered.with('3')
        expect(subject).to receive(:send_digits).once.ordered.with('12345')
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
From: "#{specs_from}" <sip:#{specs_from}@[local_ip]:[local_port]>;tag=[call_number]
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
<action><assignstr assign_to="remote_addr" value="[service]@[remote_ip]:[remote_port]"/><assignstr assign_to="local_addr" value="#{specs_from}@[local_ip]:[local_port]"/><assignstr assign_to="call_addr" value="[service]@[remote_ip]:[remote_port]"/></action></send>
  <recv response="100" optional="true"/>
  <recv response="180" optional="true"/>
  <recv response="183" optional="true"/>
  <recv response="200" rrs="true" rtd="true">
    <action>
      <ereg regexp="&lt;sip:(.*)&gt;.*;tag=([^;]*)" search_in="hdr" header="To:" assign_to="dummy,remote_addr,remote_tag"/>
    </action>
  </recv>
  <send>
<![CDATA[
ACK [next_url] SIP/2.0
Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
From: "#{specs_from}" <sip:#{specs_from}@[local_ip]:[local_port]>;tag=[call_number]
To: <sip:[service]@[remote_ip]:[remote_port]>[peer_tag_param]
Call-ID: [call_id]
CSeq: [cseq] ACK
Contact: <sip:[$local_addr];transport=[transport]>
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
Contact: <sip:[$local_addr];transport=[transport]>
Max-Forwards: 100
User-Agent: SIPp/sippy_cup
Content-Length: 0
[routes]
]]>
</send>
  <Reference variables="remote_addr,local_addr,call_addr,dummy,remote_tag"/>
</scenario>
      END
    end

    let(:override_options) { { number_of_calls: 10 } }

    it "generates the correct XML" do
      scenario = described_class.from_manifest(scenario_yaml)
      expect(scenario.to_xml(:pcap_path => "/dev/null")).to eq(scenario_xml)
    end

    it "sets the proper options" do
      scenario = described_class.from_manifest(scenario_yaml)
      expect(scenario.scenario_options).to eq({
        'name' => 'spec scenario',
        'source' => '192.0.2.15',
        'destination' => '192.0.2.200',
        'max_concurrent' => 10,
        'calls_per_second' => 5,
        'number_of_calls' => 20,
        'from_user' => "#{specs_from}"
      })
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
        expect(scenario).to be_a(SippyCup::XMLScenario)
        expect(scenario.to_xml).to eq(File.read(scenario_path))
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
          expect(files[:media].read).to eql(media)
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
- sleep 3
- send_digits '3125551234'
- sleep 5
- send_digits '#'
- wait_for_hangup
        END
      end

      it "should default to 'My Scenario'" do
        scenario = described_class.from_manifest(scenario_yaml)
        expect(scenario.scenario_options[:name]).to eq('My Scenario')
      end
    end

    context "with an input filename specified" do
      context "and a name in the manifest" do
        it "uses the name from the manifest" do
          scenario = described_class.from_manifest(scenario_yaml, input_filename: '/tmp/foobar.yml')
          expect(scenario.scenario_options[:name]).to eq('spec scenario')
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
  - sleep 3
  - send_digits '3125551234'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
          END
        end

        it "uses the input filename" do
          scenario = described_class.from_manifest(scenario_yaml, input_filename: '/tmp/foobar.yml')
          expect(scenario.scenario_options[:name]).to eq('foobar')
        end
      end
    end

    context "overriding some value" do
      let(:specs_from) { 'other_user' }

      it "overrides keys with values from the options hash" do
        scenario = described_class.from_manifest(scenario_yaml, override_options)
        expect(scenario.to_xml(:pcap_path => "/dev/null")).to eq(scenario_xml)
      end

      it "sets the proper options" do
        scenario = described_class.from_manifest(scenario_yaml, override_options)
        expect(scenario.scenario_options).to eq({
          'name' => 'spec scenario',
          'source' => '192.0.2.15',
          'destination' => '192.0.2.200',
          'max_concurrent' => 10,
          'calls_per_second' => 5,
          'number_of_calls' => override_options[:number_of_calls],
          'from_user' => "#{specs_from}"
        })
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
  - sleep 3
  - send_digits 'xyz'
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
        expect(scenario).not_to be_valid
      end

      it "sets the error messages for the scenario" do
        scenario = SippyCup::Scenario.from_manifest(scenario_yaml)
        expect(scenario.errors).to eq([{step: 4, message: "send_digits 'xyz': Invalid DTMF digit requested: x"}])
      end
    end
  end
end
