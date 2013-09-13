require 'spec_helper'

describe SippyCup::Scenario do
  let(:default_args) { {source: '127.0.0.1:5060', destination: '10.0.0.1:5080'} }

  it %q{should create a media stream on initialization} do
    SippyCup::Media.should_receive(:new).once
    SippyCup::Scenario.new 'Test', source: '127.0.0.1:5060', destination: '127.0.0.2:5061'
  end

  it %q{should take a block to generate a scenario} do
    s = SippyCup::Scenario.new 'Test', default_args do
      invite
    end

    s.to_xml.should =~ %r{INVITE sip:\[service\]@\[remote_ip\]:\[remote_port\] SIP/2.0}
  end

  it %q{should allow creating a blank scenario with no block} do
    s = SippyCup::Scenario.new 'Test', default_args
    s.invite
    s.to_xml.should =~ %r{INVITE sip:\[service\]@\[remote_ip\]:\[remote_port\] SIP/2.0}
  end

  describe '#invite' do 
    context 'no arguments' do
      let(:scenario) { SippyCup::Scenario.new 'Test', source: '127.0.0.1:1234', destination: '127.0.0.1:1234' }
      it "create a standard invite" do
        scenario.invite

        xml = scenario.to_xml
        xml.should =~ /retrans="500"/
        xml.should =~ /INVITE sip:\[service\]@\[remote_ip\]/
        xml.should_not =~ /branch=\[branch\]\n        \n/
      end
    end
    context 'static RTCP port' do
      let(:scenario) { SippyCup::Scenario.new 'Test', source: '127.0.0.1:1234', destination: '127.0.0.1:1234', rtcp_port: 6000 }
      it "should replace the standard RTP and RTCP with static ports" do
        scenario.invite
        xml = scenario.to_xml
        xml.should =~ /m=audio 5999 RTP\/AVP 0 101/
        xml.should =~ /a=rtcp:6000/
      end
    end
    context 'with headers' do
      let(:scenario) { SippyCup::Scenario.new 'Test', source: '127.0.0.1:1234', destination: '127.0.0.1:1234' }
      it "should interpolate the headers into the invite" do
        scenario.invite headers: "Route: <sip:1@localhost>"
        xml = scenario.to_xml
        xml.should =~ /\n        Route: <sip:1@localhost>\n/
      end
    end
  end

  describe '#wait_for_answer' do
    let(:scenario) { scenario = SippyCup::Scenario.new 'Test', source: '127.0.0.1:5061', destination: '127.0.0.1:5060' }

    it %q{should tell SIPp to optionally receive a SIP 100, 180 and 183 by default, while requiring a 200} do
      scenario.wait_for_answer

      xml = scenario.to_xml
      xml.should =~ /recv response="100".*optional="true"/
      xml.should =~ /recv response="180".*optional="true"/
      xml.should =~ /recv response="183".*optional="true"/
      xml.should =~ /recv response="200"/
      xml.should_not =~ /recv response="200".*optional="true"/
    end

    it %q{should pass through additional options} do
      scenario.wait_for_answer foo: 'bar'

      xml = scenario.to_xml
      xml.should =~ /recv response="100".*foo="bar"/
      xml.should =~ /recv response="180".*foo="bar"/
      xml.should =~ /recv response="183".*foo="bar"/
      xml.should =~ /recv response="200".*foo="bar"/
    end
  end

  describe 'media-dependent operations' do
    let(:media) { double :media }
    let(:scenario) do
      SippyCup::Media.should_receive(:new).once.and_return media
      scenario = SippyCup::Scenario.new 'Test', source: '127.0.0.1:5061', destination: '127.0.0.1:5060'
    end

    it %q{should create the proper amount of silent audio'} do
      media.should_receive(:<<).once.with 'silence:5000'
      scenario.sleep 5
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

  describe "#register" do
    let(:scenario) { SippyCup::Scenario.new 'Test', source: '127.0.0.1:5061', destination: '127.0.0.1:5060' }

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
      xml.should =~ %r{recv response="401" optional="false" auth="true"}
      xml.should =~ %r{\[authentication username=foo password=seekrut\]}
    end
  end

  describe "#parse_user" do
    let(:scenario) { SippyCup::Scenario.new 'Test', source: '127.0.0.1:5061', destination: '127.0.0.1:5060' }

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
end
