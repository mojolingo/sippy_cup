# develop
  * Feature: receive_message for incoming SIP MESSAGEs.
  * Change: Split `#receive_200` into its own method ([#61](https://github.com/mojolingo/sippy_cup/pull/61))
  * Allow passing arbitrary SIPp options from the YAML manifest
  * Bugfix: Fix ACK/BYE being sent to self.

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
