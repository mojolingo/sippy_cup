[![Gem Version](https://badge.fury.io/rb/sippy_cup.png)](https://rubygems.org/gems/sippy_cup)
[![Build Status](https://secure.travis-ci.org/mojolingo/sippy_cup.png?branch=master)](http://travis-ci.org/mojolingo/sippy_cup)
[![Dependency Status](https://gemnasium.com/mojolingo/sippy_cup.png?travis)](https://gemnasium.com/mojolingo/sippy_cup)
[![Code Climate](https://codeclimate.com/github/mojolingo/sippy_cup.png)](https://codeclimate.com/github/mojolingo/sippy_cup)
[![Coverage Status](https://coveralls.io/repos/mojolingo/sippy_cup/badge.png?branch=master)](https://coveralls.io/r/mojolingo/sippy_cup)

# Sippy Cup

## Overview

### The Problem

Load testing voice systems, and voice applications in particular, is tricky.  While several commercial tools exist, there is really only one tool in the Open Source world that is good at efficiently generating SIP load: [SIPp](http://sipp.sourceforge.net/).  While SIPp does a good job of generating load, it is somewhat clumsy to use, due to a verbose XML format for scenarios, a confusing set of command line parameters, and worst of all, a lack of tools to create media needed to interact with voice applications.

The last problem is especially tricky: Imagine you want to load test an IVR. Testing requires:

* calling a test number
* waiting a certain amount of time
* sending some DTMF
* waiting some more
* sending more DTMF
* etc....

To test this with SIPp you need a PCAP file that contains the properly timed DTMF interactions. Since there is no tool to create this media, it is usually necessary to call into the system and record the PCAP, isolate the RTP from the captured packets with something like Wireshark, then connect the pcap file into the SIPp scenario.  This process is time consuming and error prone, meaning that testing isn't done as often as it should.

SippyCup aims to help solve these problems.

### The Solution

Sippy Cup is a tool to generate [SIPp](http://sipp.sourceforge.net/) load test profiles and the corresponding media in PCAP format. The goal is to take an input document that describes a load test in a very simple way (call this number, wait this many seconds, send this digit, wait a few more seconds, etc).  The ideas are taken from [LoadBot](https://github.com/mojolingo/ahn-loadbot), but the goal is for a more performant load generating tool with no dependency on Asterisk.

## Requirements

SippyCup relies on the following to generate scenarios and the associated media PCAP files:

* Ruby 1.9.3 or later (2.1.2 recommended)
* [SIPp](http://sipp.sourceforge.net/) latest master branch - Download from https://github.com/sipp/sipp - NOTE: Version SIPp version 3.4 may work, but will be missing certain new Sippy Cup features, such as rate scaling
* "root" user access via sudo: needed to run SIPp so it can bind to raw network sockets

## Installation

If you do not have Ruby 2.1.2 available (check using `ruby --version`), we recommend installing Ruby with [RVM](http://rvm.io)

### Install via gem (production)

Once Ruby is installed, install SippyCup:

```
gem install sippy_cup
```

Now you can start creating scenario files like in the examples below.

### Install from repository (development)

You use `bundle` command (from the "[bundler](http://bundler.io/)" package) to install from the source directly. First, clone the repository into a working directory.

Install `bundle` via gem:

```
gem install bundler --no-ri --no-rdoc
```

Then build the `sippy_cup` application with `bundle`.

```
bundle install
```

Using `bundle` will then install the gem dependencies and allow you to run `sippy_cup` from your working directory.

## Examples

### Simple Example

```YAML
---
source: 192.0.2.15
destination: 192.0.2.200
max_concurrent: 10
calls_per_second: 5
number_of_calls: 20
steps:
  - invite
  - wait_for_answer
  - ack_answer
  - sleep 3
  - send_digits '3125551234'
  - sleep 5
  - send_digits '#'
  - wait_for_hangup
```

Both `source` and `destination` above may be optionally supplied with a port number, eg. `192.0.2.200:5061`

Next, execute the scenario:

```Shell
$ sippy_cup -r my_test_scenario.yml
I, [2013-09-30T14:48:08.388106 #9883]  INFO -- : Preparing to run SIPp command: sudo sipp -i 192.0.2.15 -p 8836 -sf /var/folders/n4/dpzsp6_95tb3c4sp12xj5wdr0000gn/T/scenario20130930-9883-1crejcw -l 10 -m 20 -r 5 -s 1 192.0.2.200
Password:

...snip...

I, [2013-09-30T14:48:16.728712 #9883]  INFO -- : Test completed successfully.
```

More examples are [available in the source repository](https://github.com/mojolingo/sippy_cup/tree/develop/examples).

### Example embedding SIPp in another Ruby process

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

  s.wait_for_hangup
end

# Create the scenario XML and PCAP media. File will be named after the scenario name, in our case:
# * sippy_cup.xml
# * sippy_cup.pcap
scenario.compile!
```

The above code can be executed as a standalone Ruby script and the resulting scenario file run with SIPp.

## Customize Your Scenarios

### Available Scenario Steps

Each command below can take [SIPp attributes](http://sipp.sourceforge.net/doc/reference.html) as optional arguments. For a full list of available steps with arguments explained, see the [API documentation](http://rubydoc.info/gems/sippy_cup/SippyCup/Scenario).

* `sleep <seconds>` Wait a specified number of seconds
* `invite` Send a SIP INVITE to the specified target
* `receive_invite` Wait for an INVITE to be received
* `register <username> [password]` Register the specified user to the target with an optional password
* `send_trying` Send a `100 Trying` provisional response
* `receive_trying` Expect to receive a `100 Trying` response from the target
* `send_ringing` Send a `180 Ringing` provisional response
* `receive_ringing` Expect to receive a `180 Ringing` response from the target
* `receive_progress` Expect to receive a `183 Progress` response from the target
* `send_answer` Send a `200 Ok` response to an INVITE (answer the call)
* `receive_answer` Expect to receive a `200 OK` (answering the call) response from the target
* `answer` Convenient shortcut for `send_answer; receive_ack`
* `wait_for_answer` Convenient shortcut for `receive_trying; receive_ringing; receive_progress; receive_answer`, with all but the `answer` marked as optional
* `ack_answer` Send an `ACK` in response to a `200 OK`
* `receive_ack` Expect to receive an `ACK`
* `send_digits <string>` Send a DTMF string. May send one or many digits, including `0-9`, `*`, `#`, and `A-D`
* `receive_ok` Expect to receive a `200 OK`
* `receive_message [regex]` Expect to receive a SIP MESSAGE, optionally matching a regex
* `send_bye` Send a `BYE` (hangup request)
* `receive_bye` Expect to receive a `BYE` from the target
* `ack_bye` Send a `200 OK` response to a `BYE`
* `wait_for_hangup` Convenient shortcut for `receive_bye; ack_bye`
* `hangup` Convenient shortcut for `send_bye; receive_ok`
* `call_length_repartition` Creates a histogram table of individual call lengths in milliseconds between min length and max length, at the specified interval
* `response_time_repartition` Creates a histogram table of individual SIP request response times in milliseconds between min length and max length, at the specified interval

### Alternate Output File Path

Don't want your scenario to end up in the same directory as your script? Need the filename to be different than the scenario name? No problem!

For the `sippy_cup` manifest, use `filename`:

```YAML
---
filename: /path/to/somewhere
```

Or, in Ruby:

```Ruby
s = SippyCup::Scenario.new 'SippyCup', source: '192.168.5.5:10001', destination: '10.10.0.3:19995', filename: '/path/to/somewhere' do
  # scenario definitions here...
end
s.compile!
```

This will create the files `somewhere.xml` and `somewhere.pcap` in the `/path/to/` directory.

### Customizing the Test Run

Each parameter has an impact on the test, and may either be changed once the XML file is generated or specified in the options hash for `SippyCup::Scenario.new`. In addition to the default parameters, some additional parameters can be set:

<dl>
  <dt>stats_file</dt>
  <dd>Path to a file where call statistics will be stored in a CSV format, defaults to not storing stats</dd>

  <dt>stats_interval</dt>
  <dd>Frequency (in seconds) of statistics collections. Defaults to 10. Has no effect unless :stats_file is also specified</dd>

  <dt>from_user</dt>
  <dd>SIP user from which traffic should appear. Default: sipp</dd>

  <dt>to_user</dt>
  <dd>SIP user to send requests to. Defaults to SIPp's default: `s` (as in `s@127.0.0.1`)</dd>

  <dt>to_domain</dt>
  <dd>SIP domain to send requests to. Defaults to the same as `destination`. Useful for testing multi-tenant systems where the `To` domain is not the same as the hostname of the system.</dd>

  <dt>transport</dt>
  <dd>Specify the SIP transport. Valid options are `udp` (default) or `tcp`. Default: `udp`</dd>

  <dt>full_sipp_output</dt>
  <dd>By default, SippyCup will show SIPp's command line output while running a scenario. Set this parameter to `false` to hide full command line output. Default: `true`</dd>

  <dt>summary_report_file</dt>
  <dd>Write a summary of the SIPp run to the specified file. This summary is the output from the SIPp `-trace_screen` command. Default: unused</dd>

  <dt>errors_report_file</dt>
  <dd>Record SIPp's errors to the specified file. This report is the output from the SIPp `-trace_err` command. Default: unused</dd>

  <dt>options</dt>
  <dd>A string of SIPp command line options included with the SIPp run. Default: none</dd>

  <dt>media_port</dt>
  <dd>By default, SIPp assigns RTP ports dynamically. However, if there is a need for a static RTP port (say, for data collection purposes), it can be done by supplying a port number here. Default: SIPp's default of 6000</dd>

  <dt>dtmf_mode</dt>
  <dd>Specify the mechanism by which DTMF is signaled. Valid options are `rfc2833` for within the RTP media, or `info` for SIP INFO. Default: rfc2833</dd>

  <dt>scenario_variables</dt>
  <dd>If you're using sippy_cup to run a SIPp XML file, there may be CSV fields in the scenario ([field0], [field1], etc.). Specify a path to a CSV file containing the required information using this option. (File is semicolon delimeted, information can be found [here](http://sipp.sourceforge.net/doc/reference.html#inffile).) Default: unused</dd>

  <dt>number_of_calls</dt>
  <dd>The total number of calls permitted for the entire test. When this limit is reached, the test is over. Defaults to none - test will run forever until manually stopped</dd>

  <dt>number_of_calls</dt>
  <dd>The total number of calls permitted for the entire test. When this limit is reached, the test is over. Defaults to nil.</dd>

  <dt>concurrent_max</dt>
  <dd>The maximum number of calls permitted to be active at any given time. When this limit is reached, SIPp will slow down or stop sending new calls until there it falls below the limit. Defaults to SIPp's default: (3 * call_duration (seconds) * calls_per_second)</dd>

  <dt>calls_per_second</dt>
  <dd>The rate at which new calls should be created. Note that SIPp will automatically adjust this downward to stay at or beneath the maximum number of concurrent calls (`concurrent_max`). Defaults to SIP's default of 10</dt>

  <dt>calls_per_second_incr</dt>
  <dd>When used with `calls_per_second_max`, tells SIPp the amount by which `calls_per_second` should be incremented. CPS rate is adjusted each `calls_per_second_interval`. Default: 1.</dd>

  <dt>calls_per_second_interval</dt>
  <dd>When used with `calls_per_second_max`, tells SIPp the time interval (in seconds) by which calls-per-second should be incremented. Default: Unset; SIPp's default (60s). NOTE: Requires a development build of SIPp; see https://github.com/SIPp/sipp/pull/107</dd>

  <dt>calls_per_second_max</dt>
  <dd>The maximum rate of calls-per-second. Default: unused (`calls_per_second` will not change)</dd>

  <dt>advertise_address</dt>
  <dd>The IP address to advertise in SIP and SDP if different from the bind IP. Default: `source` IP address</dd>
</dl>

### Additional SIPp Scenario Attributes

With Sippy Cup, you can add additional attributes to each step of the scenario:

```Ruby
# This limits the amount of time the server has to reply to an invite (3 seconds)
s.receive_answer timeout: 3000

# You can override the default 'optional' parameters
s.receive_ringing optional: false
s.receive_answer optional: true

# Let's combine multiple attributes...
s.receive_answer timeout: 3000, crlf: true
```

For more information on possible attributes, visit the [SIPp Documentation](http://sipp.sourceforge.net/doc/reference.html).

## Credits

Copyright (C) 2013-2014 [Mojo Lingo LLC](https://mojolingo.com)

Sippy Cup is released under the [MIT license](http://opensource.org/licenses/MIT). Please see the [LICENSE](https://github.com/bklang/sippy_cup/blob/master/LICENSE) file for details.

Sippy Cup was created by [Ben Klang](https://twitter.com/bklang) and [Will Drexler](https://github.com/wdrexler) with support from [Mojo Lingo](https://mojolingo.com) and their clients.

"Sippy Cup" name suggested by [Jamey Owens](https://github.com/vindir)
