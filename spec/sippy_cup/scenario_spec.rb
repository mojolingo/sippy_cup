require 'spec_helper'

describe SippyCup::Scenario do
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
end
