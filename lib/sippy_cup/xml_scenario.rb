# encoding: utf-8
require 'tempfile'

module SippyCup
  #
  # A representation of a SIPp XML scenario
  #
  class XMLScenario
    # @return [Hash] The options the scenario was created with, either from a manifest or passed as overrides
    attr_reader :scenario_options

    #
    # Create a scenario instance
    #
    # @param [String] name The scenario's name
    # @param [String] xml The XML document representing the scenario
    # @param [String] media The media to be invoked by the scenario in PCAP format
    # @param [Hash] args options to customise the scenario. @see Scenario#initialize.
    #
    def initialize(name, xml, media, args = {})
      @xml, @media = xml, media
      @scenario_options = args.merge name: name
    end

    #
    # Write compiled Scenario XML and PCAP media to tempfiles.
    #
    # These will automatically be closed and deleted once they have gone out of scope, and can be used to execute the scenario without leaving stuff behind.
    #
    # @return [Hash<Symbol => Tempfile>] handles to created Tempfiles at :scenario and :media
    #
    # @see http://www.ruby-doc.org/stdlib-1.9.3/libdoc/tempfile/rdoc/Tempfile.html
    #
    def to_tmpfiles
      scenario_file = Tempfile.new 'scenario'
      scenario_file.write @xml
      scenario_file.rewind

      if @media
        media_file = Tempfile.new 'media'
        media_file.write @media
        media_file.rewind
      else
        media_file = nil
      end

      {scenario: scenario_file, media: media_file}
    end

    #
    # Dump the scenario to a SIPp XML string
    #
    # @return [String] the SIPp XML scenario
    def to_xml
      @xml
    end
  end
end
