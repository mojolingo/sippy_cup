Sippy Cup
=========

Sippy Cup is a tool to generate [SIPp](http://sipp.sourceforge.net/) load test profiles and the corresponding media in PCAP format. The goal is to take an input document that describes a load test in a very simple way (call this number, wait this many seconds, send this digit, wait a few more seconds, etc).  The ideas are taken from [LoadBot](https://github.com/mojolingo/ahn-loadbot), but the goal is for a more performant load generating tool with no dependency on Asterisk.


Requirements
------------

SippyCup relies on the following to generate scenarios and the associated media PCAP files:

* Ruby 1.9.3 (2.0.0 NOT YET SUPPORTED; see [PacketFu Issue #28](https://github.com/todb/packetfu/issues/28)
* [SIPp](http://sipp.sourceforge.net/) - Download from http://sourceforge.net/projects/sipp/files/


Installation
------------

If you do not have Ruby 1.9.3 available (check using `ruby --version`), we recommend installing Ruby with [RVM](http://rvm.io)

Once Ruby is installed, install SippyCup:

```
gem install sippy_cup
```

Now you can start creating scenario files like in the examples below.


Example
-------

```Ruby
require 'sippy_cup'

scenario = SippyCup::Scenario.new 'Sippy Cup', source: '192.168.5.5:10001', destination: '10.10.0.3:19995' do |s|
  s.invite
  s.wait_for_answer
  s.ack_answer

  s.sleep 3
  s.send_digits '3125551234'
  s.sleep 5
  s.send_digits '#'

  s.receive_bye
  s.ack_bye
end

# Create the scenario XML and PCAP media. File will be named after the scenario name, in our case:
# * sippy_cup.xml
# * sippy_cup.pcap
scenario.compile!
```

Customize Your Scenarios
------------------------

With Sippy Cup, you can add additional attributes to each step of the scenario:
```Ruby

#This limits the amount of time the server has to reply to an invite (3 seconds)
s.receive_answer timeout: 3000

#You can override the default 'optional' parameters
s.receive_ringing optional: false
s.receive_answer optional: true

#Let's combine multiple attributes...
s.receive_answer timeout: 3000, crlf: true
```

For more information on possible attributes, visit the [SIPp Documentation](http://sipp.sourceforge.net/doc/reference.html)
