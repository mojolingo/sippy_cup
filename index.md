---
layout: default
---

# <a name="sippy-cup" class="anchor" href="#sippy-cup"><span class="octicon octicon-link"></span></a>Sippy Cup

### <a name="the-problem" class="anchor" href="#the-problem"><span class="octicon octicon-link"></span></a>The Problem

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

### <a name="the-solution" class="anchor" href="#the-solution"><span class="octicon octicon-link"></span></a>The Solution

Sippy Cup is a tool to generate [SIPp](http://sipp.sourceforge.net/) load test profiles and the corresponding media in PCAP format. The goal is to take an input document that describes a load test in a very simple way (call this number, wait this many seconds, send this digit, wait a few more seconds, etc).  The ideas are taken from [LoadBot](https://github.com/mojolingo/ahn-loadbot), but the goal is for a more performant load generating tool with no dependency on Asterisk.

## <a name="requirements" class="anchor" href="#requirements"><span class="octicon octicon-link"></span></a>Requirements

SippyCup relies on the following to generate scenarios and the associated media PCAP files:

* Ruby 1.9.3 (2.0.0 NOT YET SUPPORTED; see [PacketFu Issue #28](https://github.com/todb/packetfu/issues/28)
* [SIPp](http://sipp.sourceforge.net/) - Download from http://sourceforge.net/projects/sipp/files/

## <a name="installation" class="anchor" href="#installation"><span class="octicon octicon-link"></span></a>Installation

If you do not have Ruby 1.9.3 available (check using `ruby --version`), we recommend installing Ruby with [RVM](http://rvm.io)

Once Ruby is installed, install SippyCup:

```
gem install sippy_cup
```

Now you can start creating scenario files like in the examples below.

## <a name="example" class="anchor" href="#example"><span class="octicon octicon-link"></span></a>Example

<div class="highlight"><pre><span class="nb">require</span> <span class="s1">'sippy_cup'</span>

<span class="n">scenario</span> <span class="o">=</span> <span class="ss">SippyCup</span><span class="p">:</span><span class="ss">:Scenario</span><span class="o">.</span><span class="n">new</span> <span class="s1">'Sippy Cup'</span><span class="p">,</span> <span class="ss">source</span><span class="p">:</span> <span class="s1">'192.168.5.5:10001'</span><span class="p">,</span> <span class="ss">destination</span><span class="p">:</span> <span class="s1">'10.10.0.3:19995'</span> <span class="k">do</span> <span class="o">|</span><span class="n">s</span><span class="o">|</span>
  <span class="n">s</span><span class="o">.</span><span class="n">invite</span>
  <span class="n">s</span><span class="o">.</span><span class="n">wait_for_answer</span>
  <span class="n">s</span><span class="o">.</span><span class="n">ack_answer</span>

  <span class="n">s</span><span class="o">.</span><span class="n">sleep</span> <span class="mi">3</span>
  <span class="n">s</span><span class="o">.</span><span class="n">send_digits</span> <span class="s1">'3125551234'</span>
  <span class="n">s</span><span class="o">.</span><span class="n">sleep</span> <span class="mi">5</span>
  <span class="n">s</span><span class="o">.</span><span class="n">send_digits</span> <span class="s1">'#'</span>

  <span class="n">s</span><span class="o">.</span><span class="n">receive_bye</span>
  <span class="n">s</span><span class="o">.</span><span class="n">ack_bye</span>
<span class="k">end</span>

<span class="c1"># Create the scenario XML, PCAP media, and YAML options. File will be named after the scenario name, in our case:</span>
<span class="c1"># * sippy_cup.xml</span>
<span class="c1"># * sippy_cup.yml</span>
<span class="c1"># * sippy_cup.pcap</span>
<span class="n">scenario</span><span class="o">.</span><span class="n">compile!</span>
</pre></div>

The above code can either be executed as a standalone Ruby script and run with SIPp, or it can be compiled and run using rake tasks by inserting the following code into your Rakefile:

<div class="highlight"><pre><span class="nb">require</span> <span class="s1">'sippy_cup/tasks'</span>
</pre></div>

Then running the rake task `rake sippy_cup:compile[sippy_cup.rb]` 

And finally running `rake sippy_cup:run[sippy_cup.yml]` to execute the scenario.

## <a name="customize-your-scenarios" class="anchor" href="#customize-your-scenarios"><span class="octicon octicon-link"></span></a>Customize Your Scenarios

### <a name="alternate-file-path" class="anchor" href="#alternate-file-path"><span class="octicon octicon-link"></span></a>Alternate File Path

Don't want your scenario to end up in the same directory as your script? Need the filename to be different than the scenario name? No problem! Try:

<div class="highlight"><pre><span class="n">my_opts</span> <span class="o">=</span> <span class="p">{</span> <span class="ss">source</span><span class="p">:</span> <span class="s1">'192.168.5.5:10001'</span><span class="p">,</span> <span class="ss">destination</span><span class="p">:</span> <span class="s1">'10.10.0.3:19995'</span><span class="p">,</span> <span class="ss">filename</span><span class="p">:</span> <span class="s1">'/path/to/somewhere'</span> <span class="p">}</span>
<span class="n">s</span> <span class="o">=</span> <span class="ss">SippyCup</span><span class="p">:</span><span class="ss">:Scenario</span><span class="o">.</span><span class="n">new</span> <span class="s1">'SippyCup'</span><span class="p">,</span> <span class="n">my_opts</span> <span class="k">do</span>
  <span class="o">.</span><span class="n">.</span><span class="o">.</span>
<span class="k">end</span>
</pre></div>

This will create the files `somewhere.xml`, `somewhere.pcap`, and `somewhere.yml` in the `/path/to/` directory.

### <a name="customizing-the-test-run" class="anchor" href="#customizing-the-test-run"><span class="octicon octicon-link"></span></a>Customizing the Test Run

By default, sippy cup will automatically generate a YAML file with the following contents:

<div class="highlight"><pre><span class="nn">---</span>
<span class="l-Scalar-Plain">:source</span><span class="p-Indicator">:</span> <span class="l-Scalar-Plain">127.0.0.1</span>
<span class="l-Scalar-Plain">:destination</span><span class="p-Indicator">:</span> <span class="l-Scalar-Plain">127.0.0.1</span>
<span class="l-Scalar-Plain">:scenario</span><span class="p-Indicator">:</span> <span class="l-Scalar-Plain">/path/to/scenario.xml</span>
<span class="l-Scalar-Plain">:max_concurrent</span><span class="p-Indicator">:</span> <span class="l-Scalar-Plain">10</span>
<span class="l-Scalar-Plain">:calls_per_second</span><span class="p-Indicator">:</span> <span class="l-Scalar-Plain">5</span>
<span class="l-Scalar-Plain">:number_of_calls</span><span class="p-Indicator">:</span> <span class="l-Scalar-Plain">20</span>
</pre></div>

Each parameter has an impact on the test, and may either be changed once the YAML file is generated or specified in the options hash for <code>SippyCup::Scenario.new</code>. In addition to the default parameters, some additional parameters can be set:

<dl>
<dt>:source_port:</dt>
  <dd>The local port from which to originate SIP traffic. This defaults to port 8836</dd>

  <dt>:stats_file:</dt>
  <dd>Path to a file where call statistics will be stored in a CSV format, defaults to not storing stats</dd>

  <dt>:stats_interval</dt>
  <dd>Frequency (in seconds) of statistics collections. Defaults to 10. Has no effect unless :stats_file is also specified</dd>

  <dt>:sip_user:</dt>
  <dd>SIP username to use. Defaults to "1" (as in 1@127.0.0.1)</dd>

  <dt>:full_sipp_output:</dt>
  <dd>By default, SippyCup will hide SIPp's command line output while running a scenario. Set this parameter to `true` to see full command line output</dd>
</dl>

### <a name="additional-sipp-attributes" class="anchor" href="#additional-sipp-attributes"><span class="octicon octicon-link"></span></a>Additional SIPp Attributes

With Sippy Cup, you can add additional attributes to each step of the scenario:

<div class="highlight"><pre>
<span class="c1">#This limits the amount of time the server has to reply to an invite (3 seconds)</span>
<span class="n">s</span><span class="o">.</span><span class="n">receive_answer</span> <span class="ss">timeout</span><span class="p">:</span> <span class="mi">3000</span>

<span class="c1">#You can override the default 'optional' parameters</span>
<span class="n">s</span><span class="o">.</span><span class="n">receive_ringing</span> <span class="ss">optional</span><span class="p">:</span> <span class="kp">false</span>
<span class="n">s</span><span class="o">.</span><span class="n">receive_answer</span> <span class="ss">optional</span><span class="p">:</span> <span class="kp">true</span>

<span class="c1">#Let's combine multiple attributes...</span>
<span class="n">s</span><span class="o">.</span><span class="n">receive_answer</span> <span class="ss">timeout</span><span class="p">:</span> <span class="mi">3000</span><span class="p">,</span> <span class="ss">crlf</span><span class="p">:</span> <span class="kp">true</span>
</pre></div>

For more information on possible attributes, visit the <a href="http://sipp.sourceforge.net/doc/reference.html">SIPp Documentation</a>
