# develop

# [0.6.0](https://github.com/mojolingo/sippy_cup/compare/v0.5.0...v0.6.0)
  * Change: Call limits (`number_of_calls`, `concurrent_max` and `calls_per_second`) no longer have default values for simplicity of UAS scenarios. The value of `to_user` now defaults to the SIPp default of `s`.
  * Feature: Support for setting rate scaling independently of reporting frequency via the new `calls_per_second_interval` option. See also https://github.com/SIPp/sipp/pull/107 and https://github.com/SIPp/sipp/pull/126.

# [0.5.0](https://github.com/mojolingo/sippy_cup/compare/v0.4.1...v0.5.0)
SYNTAX CHANGES!
This is a backward incompatible change. If upgrading from Sippy Cup 0.4.x please see the [documentation](http://mojolingo.github.io/sippy_cup/#available-scenario-steps) and the `Change` items below.
You will also need to compile the latest [SIPp from Github](https://github.com/sipp/sipp) to make use of all the features.
  * Feature: Add support for saving screen and error reports to specified files
  * Feature: Add support for UAS actions (waiting for an incoming call)
  * Feature: Permit supplying a SIP advertise address that is different from the bind IP for NAT traversal purposes
  * Feature: Add support for CallLengthRepartition and ResponseTimeRepartition tables
  * Bugfix: Much improved support for sending a hangup from SIPp, rather than waiting for the far end to do it
  * Bugfix: If scenario compilation fails on the CLI, explain why
  * Change: Rework the `register` command so it works without any other expectations
  * Change: `wait_for_answer` now includes `ack_answer`
  * Documentation: Create `examples/` directory with example scenarios

# [0.4.1](https://github.com/bklang/sippy_cup/compare/v0.4.0...v0.4.1)
  * Bugfix: Fix some Ruby 2 string encoding problems
  * Bugfix: Fix backward alias of `respond_ok` with `respond_200`

# [0.4.0](https://github.com/bklang/sippy_cup/compare/v0.3.0...v0.4.0)
  * Feature: receive_message for incoming SIP MESSAGEs.
  * Feature: SIP INFO DTMF.
  * Feature: Don't write unnecessary PCAP files.
  * Feature: Execute sipp via which, allowing sudo rule to be more restrictive.
  * Change: Split `#receive_200` into its own method ([#61](https://github.com/mojolingo/sippy_cup/pull/61))
  * Allow passing arbitrary SIPp options from the YAML manifest
  * Bugfix: Fix ACK/BYE being sent to self.
  * Bugfix: Require Psych 2.0.1 to fix `safe_load` NoMethodError (#63)
  * Bugfix: Ensure the correct XML serializer is used (#66)

# [0.3.0](https://github.com/bklang/sippy_cup/compare/v0.2.3...v0.3.0)
* Feature: A whole lot more documentation, test coverage and cleaner internals.
* Feature: Added a :transport_mode option that will add the -t switch to SIPp for setting TCP or other UDP modes.
* Feature: A YAML manifest may now reference a SIPp scenario (and media) on disk rather than providing steps.
* Feature: A media port may be specified as `:media_port` in the manifest or at runtime.
* Feature: API for validation of scenarios in manifests.
* Feature: Handle SIPp exit codes with clean exceptions.
* Feature: Allow passing arbitary headers in an INVITE
* Change: Rake tasks for executing scenarios are removed.
* Change: Running and compiling scenarios are now separate concepts.
  * `-c` on the CLI writes a YAML manifest to disk as SIPp XML and PCAP media. `-r` executes a YAML manifest and does not write to disk.
  * XML scenarios may be referenced in a YAML manifest using the `scenario:` and `media:` keys, providing paths.
  * `Runner` now takes a `Scenario` which it executes using SIPp via a temporary local-disk export. Most options passed to `Runner.new` are now properties of Scenario and can be specified in the YAML manifest. `Runner` no longer executes a scenario by path.
* Bugfix/Security: Don't symbolise untrusted data (YAML manifests).
* Bugfix: Allow the `sleep` step to take fractional seconds.
* Bugfix: Proxy full SIPp output to terminal by default.

# [0.2.3](https://github.com/bklang/sippy_cup/compare/v0.2.2...v0.2.3)
* Bugfix: Handle file extensions .yaml and .yml equally (#21)
* Bugfix: Fix missing Logger constant (#20)

# [0.2.2](https://github.com/bklang/sippy_cup/compare/v0.2.1...v0.2.2)
* Feature: Added support for REGISTER messages
* Bugfix: Enable testing through proxies
* Several enhancements to the test runner, including ability to specify a data file and the RTCP port

# [0.2.1](https://github.com/bklang/sippy_cup/compare/v0.2.0...v0.2.1)
* Bugfix: fix the name of the compiled files
* Bugfix: Fix SIPp arg to enable trace stats

# [0.2.0](https://github.com/bklang/sippy_cup/compare/v0.1.1...v0.2.0)
* Add new command-line ability to parse and run Sippy Cup YAML
* Bugfixes & documentation

# [0.1.1](https://github.com/bklang/sippy_cup/compare/v0.1.0...v0.1.1)
* Allow running SIPp directly from SippyCup
* New shortcut command for common answer scenario: #wait_for_answer
* Allow specifying output file name/location

# [0.1.0](https://github.com/bklang/sippy_cup/releases/tag/v0.1.0)
* Initial Release
