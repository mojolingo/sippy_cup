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

* Ruby 1.9.3 (2.0.0 NOT YET SUPPORTED; see [PacketFu Issue #28](https://github.com/todb/packetfu/issues/28))
* [SIPp](http://sipp.sourceforge.net/) - Download from http://sourceforge.net/projects/sipp/files/
* "root" user access via sudo: needed to run SIPp so it can bind to raw network sockets

## Installation

If you do not have Ruby 1.9.3 available (check using `ruby --version`), we recommend installing Ruby with [RVM](http://rvm.io)

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

Next, compile and run the scenario:

```Shell
$ sippy_cup -cr my_test_scenario.yml
Compiling media to /Users/bklang/src/sippy_cup/my_test_scenario.pcap...done.
Compiling scenario to /Users/bklang/src/sippy_cup/my_test_scenario.xml...done.
"Preparing to run SIPp command: sudo sipp -i 192.0.2.15 -p 8836 -sf /Users/bklang/src/sippy_cup/my_test_scenario.xml -l 10 -m 20 -r 5 -s 1 > /dev/null 2>&1"
$
```

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

The above code can either be executed as a standalone Ruby script and run with SIPp, or it can be compiled and run using rake tasks by inserting the following code into your Rakefile:
```Ruby
require 'sippy_cup/tasks'
```

Then running the rake task `rake sippy_cup:compile[sippy_cup.rb]`

And finally running `rake sippy_cup:run[sippy_cup.yml]` to execute the scenario.

## Customize Your Scenarios

### Available Scenario Steps

Each command below can take [SIPp attributes](http://sipp.sourceforge.net/doc/reference.html) as optional arguments.

* `sleep <seconds>` Wait a specified number of seconds
* `invite` Send a SIP INVITE to the specified target
* `register` Send a SIP REGISTER to the specified target
* `receive_trying` Expect to receive a `100 Trying` response from the target
* `receive_ringing` Expect to receive a `180 Ringing` response from the target
* `receive_progress` Expect to receive a `183 Progress` response from the target
* `receive_answer` Expect to receive a `200 OK` (answering the call) response from the target
* `wait_for_answer` Convenient shortcut for `receive_trying; receive_ringing; receive_progress; receive_answer`, with all but the `answer` marked as optional
* `ack_answer` Send an `ACK` in response to a `200 OK`
* `send_digits <string>` Send a DTMF string. May send one or many digits, including `0-9`, `*`, `#`, and `A-D`
* `send_bye` Send a `BYE` (hangup request)
* `receive_bye` Expect to receive a `BYE` from the target
* `ack_bye` Send a `200 OK` response to a `BYE`
* `wait_for_hangup` Convenient shortcut for `receive_bye; ack_bye`

### Alternate Output File Path

Don't want your scenario to end up in the same directory as your script? Need the filename to be different than the scenario name? No problem!

For the `sippy_cup` YAML specification, use `scenario`:

```YAML
---
scenario: /path/to/scenario.xml
```

Or, in Ruby:

```Ruby
my_opts = { source: '192.168.5.5:10001', destination: '10.10.0.3:19995', filename: '/path/to/somewhere' }
s = SippyCup::Scenario.new 'SippyCup', my_opts do
  # scenario definitions here...
end
```

This will create the files `somewhere.xml`, `somewhere.pcap`, and `somewhere.yml` in the `/path/to/` directory.

### Customizing the Test Run


Each parameter has an impact on the test, and may either be changed once the YAML file is generated or specified in the options hash for `SippyCup::Scenario.new`. In addition to the default parameters, some additional parameters can be set:
<dl>
  <dt>stats_file</dt>
  <dd>Path to a file where call statistics will be stored in a CSV format, defaults to not storing stats</dd>

  <dt>stats_interval</dt>
  <dd>Frequency (in seconds) of statistics collections. Defaults to 10. Has no effect unless :stats_file is also specified</dd>

  <dt>sip_user</dt>
  <dd>SIP username to use. Defaults to "1" (as in 1@127.0.0.1)</dd>

  <dt>full_sipp_output</dt>
  <dd>By default, SippyCup will hide SIPp's command line output while running a scenario. Set this parameter to `true` to see full command line output</dd>
</dl>

### Additional SIPp Scenario Attributes

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

For more information on possible attributes, visit the [SIPp Documentation](http://sipp.sourceforge.net/doc/reference.html).

## Credits

Copyright (C) 2013 [Mojo Lingo LLC](https://mojolingo.com)

Sippy Cup is released under the [MIT license](http://opensource.org/licenses/MIT). Please see the [LICENSE](https://github.com/bklang/sippy_cup/blob/master/LICENSE) file for details.

Sippy Cup was created by [Ben Klang](https://twitter.com/bklang) and [Will Drexler](https://github.com/wdrexler) with support from [Mojo Lingo](https://mojolingo.com) and their clients.

"Sippy Cup" name suggested by [Jamey Owens](https://github.com/vindir)
