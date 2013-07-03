Sippy Cup
---------

Sippy Cup is a tool to generate [SIPp](http://sipp.sourceforge.net/) load test profiles. The goal is to take an input document that describes a load test in a very simple way (call this number, wait this many seconds, send this digit, wait a few more seconds, etc).  The ideas are taken from [LoadBot](https://github.com/mojolingo/ahn-loadbot), but the goal is for a more performant load generating tool with no dependency on Asterisk.


Example
=======

```Ruby
require 'sippy_cup'

scenario = SippyCup::Scenario.new 'Sippy Cup', source: '192.168.5.5:10001', destination: '10.10.0.3:19995' do |s|
  s.invite
  s.receive_trying
  s.receive_ringing
  s.receive_progress

  s.receive_answer
  s.ack_answer

  s.sleep 3
  s.send_digits '3125551234'
  s.sleep 5
  s.send_digits '#'

  s.receive_bye
  s.ack_bye
end

scenario.compile!
```

Customize Your Scenarios
========================

With Sippy Cup, you can add additional attributes to each step of the scenario:
```Ruby

#This limits the amount of time the server has to reply to an invite (3 seconds)
s.receive_answer timeout: 3000

#You can override the default 'optional' parameters
s.receive_ringing optional: false
s.receive_answer optional: true
```

For more information on possible attributes, visit the [SIPp Documentation](http://sipp.sourceforge.net/doc/reference.html)
