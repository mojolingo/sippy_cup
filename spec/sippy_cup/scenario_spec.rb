require 'spec_helper'
require 'fakefs/spec_helpers'

describe SippyCup::Scenario do
  include FakeFS::SpecHelpers

  before do
    Dir.mkdir "/tmp"
    Dir.chdir "/tmp"
  end

  let(:default_args) { {source: '127.0.0.1:5060', destination: '10.0.0.1:5080'} }

  subject(:scenario) { described_class.new 'Test', default_args }

  it %q{should create a media stream on initialization} do
    SippyCup::Media.should_receive(:new).once
    subject
  end

  it %q{should take a block to generate a scenario} do
    s = described_class.new 'Test', default_args do
      invite
    end

    s.to_xml.should =~ %r{INVITE sip:\[service\]@\[remote_ip\]:\[remote_port\] SIP/2.0}
  end

  it %q{should allow creating a blank scenario with no block} do
    subject.invite
    subject.to_xml.should =~ %r{INVITE sip:\[service\]@\[remote_ip\]:\[remote_port\] SIP/2.0}
  end

  describe '#wait_for_answer' do
    it %q{should tell SIPp to optionally receive a SIP 100, 180 and 183 by default, while requiring a 200} do
      scenario.wait_for_answer

      xml = scenario.to_xml
      xml.should =~ /recv optional="true".*response="100"/
      xml.should =~ /recv optional="true".*response="180"/
      xml.should =~ /recv optional="true".*response="183"/
      xml.should =~ /recv response="200"/
      xml.should_not =~ /recv optional="true".*response="200"/
    end

    it %q{should pass through additional options} do
      scenario.wait_for_answer foo: 'bar'

      xml = scenario.to_xml
      xml.should =~ /recv .*foo="bar".*response="100"/
      xml.should =~ /recv .*foo="bar".*response="180"/
      xml.should =~ /recv .*foo="bar".*response="183"/
      xml.should =~ /recv .*foo="bar".*response="200"/
    end
  end

  describe 'media-dependent operations' do
    let(:media) { double :media }
    before do
      SippyCup::Media.should_receive(:new).once.and_return media
    end

    it %q{should create the proper amount of silent audio'} do
      media.should_receive(:<<).once.with 'silence:5000'
      scenario.sleep 5
    end

    it %q{should create the proper amount of silent audio when passed fractional seconds} do
      media.should_receive(:<<).once.with 'silence:500'
      scenario.sleep '0.5'
    end

    it %q{should create the requested DTMF string'} do
      media.should_receive(:<<).ordered.with 'dtmf:1'
      media.should_receive(:<<).ordered.with 'silence:250'
      media.should_receive(:<<).ordered.with 'dtmf:3'
      media.should_receive(:<<).ordered.with 'silence:250'
      media.should_receive(:<<).ordered.with 'dtmf:6'
      media.should_receive(:<<).ordered.with 'silence:250'
      scenario.send_digits '136'
    end
  end

  # @todo replace with deeper tests
  describe "#register" do
    it %q{should only call #register_message if only user is passed} do
      scenario.should_receive(:register_message).with 'foo', domain: "example.com"
      scenario.should_not_receive(:register_auth)
      scenario.register 'foo@example.com'
    end

    it %q{should call #register_auth if user and password are passed} do
      scenario.should_receive(:register_auth).with 'sally', 'seekrut', domain: "[remote_ip]"
      scenario.register 'sally', 'seekrut'
    end

    it %q{should not modify the passed in user if a domain is given} do
      scenario.register 'foo@example.com'

      xml = scenario.to_xml
      xml.should =~ %r{foo@example\.com}
    end

    it %q{should interpolate the target IP if no domain is given} do
      scenario.register 'sally'

      xml = scenario.to_xml
      xml.should =~ %r{sally@\[remote_ip\]}
    end

    it %q{should add an auth to registers which specify a password} do
      scenario.register 'foo@example.com', 'seekrut'

      xml = scenario.to_xml
      xml.should =~ %r{recv response="401" auth="true"}
      xml.should =~ %r{\[authentication username=foo password=seekrut\]}
    end
  end

  describe "#parse_user" do
    context "sip: prefix" do
      it %q{should return user and domain for addresses in the sip:user@domain:port format} do
        scenario.parse_user('sip:foo@example.com:1337').should == ['foo', 'example.com']
      end

      it %q{should return user and domain for addresses in the sip:user@domain format} do
        scenario.parse_user('sip:foo@example.com').should == ['foo', 'example.com']
      end

      it %q{should return user and [remote_ip] for addresses in the sip:user format} do
        scenario.parse_user('sip:foo').should == ['foo', '[remote_ip]']
      end
    end

    context "no prefix" do
      it %q{should return user and domain for addresses in the user@domain:port format} do
        scenario.parse_user('foo@example.com:1337').should == ['foo', 'example.com']
      end

      it %q{should return user and domain for addresses in the user@domain format} do
        scenario.parse_user('foo@example.com').should == ['foo', 'example.com']
      end

      it %q{should return user and [remote_ip] for a standalone username} do
        scenario.parse_user('sally').should == ['sally', '[remote_ip]']
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
</send>
  <recv optional="true" response="100"/>
  <recv optional="true" response="180"/>
  <recv optional="true" response="183"/>
  <recv response="200" rrs="true" rtd="true"/>
  <send>
<![CDATA[
        ACK [next_url] SIP/2.0
        Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
        From: "sipp" <sip:sipp@[local_ip]>;tag=[call_number]
        [last_To:]
        Call-ID: [call_id]
        CSeq: [cseq] ACK
        Contact: <sip:sipp@[local_ip]:[local_port];transport=[transport]>
        Max-Forwards: 100
        User-Agent: SIPp/sippy_cup
        Content-Length: 0
        [routes]
]]>
</send>
  <nop>
    <action>
      <exec play_pcap_audio="/tmp/test.pcap"/>
    </action>
  </nop>
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
        subject.to_xml.should == scenario_xml
      end
    end

    context "with an invalid steps definition" do
      let(:steps) { ["send_digits 'b'"] }

      it "should not raise errors" do
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
</send>
  <recv optional="true" response="100"/>
  <recv optional="true" response="180"/>
  <recv optional="true" response="183"/>
  <recv response="200" rrs="true" rtd="true"/>
  <send>
<![CDATA[
        ACK [next_url] SIP/2.0
        Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
        From: "#{specs_from}" <sip:#{specs_from}@[local_ip]>;tag=[call_number]
        [last_To:]
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
      <exec play_pcap_audio="/tmp/spec_scenario.pcap"/>
    </action>
  </nop>
  <pause milliseconds="3000"/>
  <pause milliseconds="500"/>
  <pause milliseconds="500"/>
  <pause milliseconds="500"/>
  <pause milliseconds="500"/>
  <pause milliseconds="500"/>
  <pause milliseconds="500"/>
  <pause milliseconds="500"/>
  <pause milliseconds="500"/>
  <pause milliseconds="500"/>
  <pause milliseconds="500"/>
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
      scenario.to_xml.should == scenario_xml
    end

    it "sets the proper options" do
      scenario = described_class.from_manifest(scenario_yaml)
      scenario.scenario_options.should == {
        name: 'spec scenario',
        source: '192.0.2.15',
        destination: '192.0.2.200',
        max_concurrent: 10,
        calls_per_second: 5,
        number_of_calls: 20,
        from_user: "#{specs_from}"
      }
    end

    context "overriding some value" do
      let(:specs_from) { 'other_user' }

      it "overrides keys with values from the options hash" do
        scenario = described_class.from_manifest(scenario_yaml, override_options)
        scenario.to_xml.should == scenario_xml
      end

      it "sets the proper options" do
        scenario = described_class.from_manifest(scenario_yaml, override_options)
        scenario.scenario_options.should == {
          name: 'spec scenario',
          source: '192.0.2.15',
          destination: '192.0.2.200',
          max_concurrent: 10,
          calls_per_second: 5,
          number_of_calls: override_options[:number_of_calls],
          from_user: "#{specs_from}"
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
