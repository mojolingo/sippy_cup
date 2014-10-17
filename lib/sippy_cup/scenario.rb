# encoding: utf-8
require 'nokogiri'
require 'psych'
require 'active_support/core_ext/hash'
require 'tempfile'
require 'set'

module SippyCup
  #
  # A representation of a SippyCup scenario from a manifest or created in code. Allows building a scenario from a set of basic primitives, and then exporting to SIPp scenario files, including the XML scenario and PCAP audio.
  #
  class Scenario
    USER_AGENT = "SIPp/sippy_cup"
    VALID_DTMF = %w{0 1 2 3 4 5 6 7 8 9 0 * # A B C D}.freeze
    MSEC = 1_000
    DEFAULT_RETRANS = 500

    #
    # Build a scenario based on either a manifest string or a file handle. Manifests are supplied in YAML format.
    # All manifest keys can be overridden by passing in a Hash of corresponding values.
    #
    # @param [String, File] manifest The YAML manifest
    # @param [Hash] options Options to override (see #initialize)
    # @option options [String] :input_filename The name of the input file if there is one. Used as a preferable fallback if no name is included in the manifest.
    #
    # @return [SippyCup::Scenario]
    #
    # @example Parse a manifest string
    #   manifest = <<-MANIFEST
    #     source: 192.168.1.1
    #     destination: 192.168.1.2
    #     steps:
    #       - invite
    #       - wait_for_answer
    #       - ack_answer
    #       - sleep 3
    #       - wait_for_hangup
    #     MANIFEST
    #   Scenario.from_manifest(manifest)
    #
    # @example Parse a manifest file by path
    #   File.open("/my/manifest.yml") { |f| Scenario.from_manifest(f) }
    #   # or
    #   Scenario.from_manifest(File.read("/my/manifest.yml"))
    #
    # @example Override keys from the manifest
    #   Scenario.from_manifest(manifest, source: '192.168.12.1')
    #
    def self.from_manifest(manifest, options = {})
      args = ActiveSupport::HashWithIndifferentAccess.new(Psych.safe_load(manifest)).merge options

      input_name = options.has_key?(:input_filename) ? File.basename(options[:input_filename]).gsub(/\.ya?ml/, '') : nil
      name = args.delete(:name) || input_name || 'My Scenario'

      scenario = if args[:scenario]
        media = args.has_key?(:media) ? File.read(args[:media], mode: 'rb') : nil
        SippyCup::XMLScenario.new name, File.read(args[:scenario]), media, args
      else
        steps = args.delete :steps
        scenario = Scenario.new name, args
        scenario.build steps
        scenario
      end

      scenario
    end

    # @return [Hash] The options the scenario was created with, either from a manifest or passed as overrides
    attr_reader :scenario_options

    # @return [Array<Hash>] a collection of errors encountered while building the scenario.
    attr_reader :errors

    #
    # Create a scenario instance
    #
    # @param [String] name The scenario's name
    # @param [Hash] args options to customise the scenario
    # @option options [String] :name The name of the scenario, used for the XML scenario and for determining the compiled filenames. Defaults to 'My Scenario'.
    # @option options [String] :filename The name of the files to be saved to disk.
    # @option options [String] :source The source IP/hostname with which to invoke SIPp.
    # @option options [String, Numeric] :source_port The source port to bind SIPp to (defaults to 8836).
    # @option options [String] :destination The target system at which to direct traffic.
    # @option options [String] :from_user The SIP user from which traffic should appear.
    # @option options [String] :to_user The SIP user to send requests to.
    # @option options [Integer] :media_port The RTCP (media) port to bind to locally.
    # @option options [String, Numeric] :max_concurrent The maximum number of concurrent calls to execute.
    # @option options [String, Numeric] :number_of_calls The maximum number of calls to execute in the test run.
    # @option options [String, Numeric] :calls_per_second The rate at which to initiate calls.
    # @option options [String] :stats_file The path at which to dump statistics.
    # @option options [String, Numeric] :stats_interval The interval (in seconds) at which to dump statistics (defaults to 1s).
    # @option options [String] :transport_mode The transport mode over which to direct SIP traffic.
    # @option options [String] :dtmf_mode The output DTMF mode, either rfc2833 (default) or info.
    # @option options [String] :scenario_variables A path to a CSV file of variables to be interpolated with the scenario at runtime.
    # @option options [Hash] :options A collection of options to pass through to SIPp, as key-value pairs. In cases of value-less options (eg -trace_err), specify a nil value.
    # @option options [Array<String>] :steps A collection of steps
    #
    # @yield [scenario] Builder block to construct scenario
    # @yieldparam [Scenario] scenario the initialized scenario instance
    #
    def initialize(name, args = {}, &block)
      parse_args args

      @scenario_options = args.merge name: name
      @filename = args[:filename] || name.downcase.gsub(/\W+/, '_')
      @filename = File.expand_path @filename, Dir.pwd
      @media = nil
      @message_variables = 0
      # Reference variables don't generate warnings/errors if unused in the scenario
      @reference_variables = Set.new
      @media_nodes = []
      @errors = []

      instance_eval &block if block_given?
    end

    # @return [true, false] the validity of the scenario. Will be false if errors were encountered while building the scenario from a manifest
    def valid?
      @errors.size.zero?
    end

    #
    # Build the scenario steps provided
    #
    # @param [Array<String>] steps A collection of steps to build the scenario
    #
    def build(steps)
      raise ArgumentError, "Must provide scenario steps" unless steps
      steps.each_with_index do |step, index|
        begin
          instruction, args = step.split ' ', 2
          args = split_quoted_string args
          if args && !args.empty?
            self.__send__ instruction, *args
          else
            self.__send__ instruction
          end
        rescue => e
          @errors << {step: index + 1, message: "#{step}: #{e.message}"}
        end
      end
    end

    #
    # Send an invite message
    #
    # @param [Hash] opts A set of options to modify the message
    # @option opts [Integer] :retrans
    # @option opts [String] :headers Extra headers to place into the INVITE
    #
    def invite(opts = {})
      opts[:retrans] ||= 500
      # FIXME: The DTMF mapping (101) is hard-coded. It would be better if we could
      # get this from the DTMF payload generator
      from_addr = "#{@from_user}@[local_ip]:[local_port]"
      to_addr   = "[service]@[remote_ip]:[remote_port]"
      msg = <<-MSG

INVITE sip:#{to_addr} SIP/2.0
Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
From: "#{@from_user}" <sip:#{from_addr}>;tag=[call_number]
To: <sip:#{to_addr}>
Call-ID: [call_id]
CSeq: [cseq] INVITE
Contact: <sip:#{from_addr};transport=[transport]>
Max-Forwards: 100
User-Agent: #{USER_AGENT}
Content-Type: application/sdp
Content-Length: [len]
#{opts.has_key?(:headers) ? opts.delete(:headers).sub(/\n*\Z/, "\n") : ''}
v=0
o=user1 53655765 2353687637 IN IP[local_ip_type] [local_ip]
s=-
c=IN IP[media_ip_type] [media_ip]
t=0 0
m=audio [media_port] RTP/AVP 0 101
a=rtpmap:0 PCMU/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-15
      MSG
      send msg, opts do |send|
        send << doc.create_element('action') do |action|
          action << doc.create_element('assignstr') do |assignstr|
            assignstr['assign_to'] = "remote_addr"
            assignstr['value']     = to_addr
          end
          action << doc.create_element('assignstr') do |assignstr|
            assignstr['assign_to'] = "local_addr"
            assignstr['value']     = from_addr
          end
          action << doc.create_element('assignstr') do |assignstr|
            assignstr['assign_to'] = "call_addr"
            assignstr['value']     = to_addr
          end
        end
      end
      # These variables will only be used if we initiate a hangup
      @reference_variables += %w(remote_addr local_addr call_addr)
    end

    #
    # Send a REGISTER message with the specified credentials
    #
    # @param [String] user the user to register as. May be given as a full SIP URI (sip:user@domain.com), in email-address format (user@domain.com) or as a simple username ('user'). If no domain is supplied, the source IP from SIPp will be used.
    # @param [optional, String, nil] password the password to authenticate with.
    # @param [Hash] opts A set of options to modify the message
    #
    # @example Register with authentication
    #   s.register 'frank@there.com', 'abc123'
    #
    # @example Register without authentication or a domain
    #   s.register 'frank'
    #
    def register(user, password = nil, opts = {})
      send_opts = opts.dup
      send_opts[:retrans] ||= DEFAULT_RETRANS
      user, domain = parse_user user
      if password
        send register_message(domain, user), send_opts
        recv opts.merge(response: 401, auth: true, optional: false)
        send register_auth(domain, user, password), send_opts
        receive_ok opts.merge(optional: false)
      else
        send register_message(domain, user), send_opts
      end
    end

    #
    # Expect to receive a SIP INVITE
    #
    # @param [Hash] opts A set of options containing SIPp <recv> element attributes
    #
    def receive_invite(opts = {})
      recv(opts.merge(request: 'INVITE', rrs: true)) do |recv|
        action = doc.create_element('action') do |action|
          action << doc.create_element('ereg') do |ereg|
            ereg['regexp'] = '<sip:(.*)>.*;tag=([^;]*)'
            ereg['search_in'] = 'hdr'
            ereg['header'] = 'From:'
            ereg['assign_to'] = 'dummy,remote_addr,remote_tag'
          end
          action << doc.create_element('ereg') do |ereg|
            ereg['regexp'] = '<sip:(.*)>'
            ereg['search_in'] = 'hdr'
            ereg['header'] = 'To:'
            ereg['assign_to'] = 'dummy,local_addr'
          end
          action << doc.create_element('assignstr') do |assignstr|
            assignstr['assign_to'] = "call_addr"
            assignstr['value']     = "[$local_addr]"
          end
        end
        recv << action
      end
      # These variables (except dummy) will only be used if we initiate a hangup
      @reference_variables += %w(dummy remote_addr remote_tag local_addr call_addr)
    end
    alias :wait_for_call :receive_invite

    #
    # Send a "100 Trying" response
    #
    # @param [Hash] opts A set of options containing SIPp <recv> element attributes
    #
    def send_trying(opts = {})
      msg = <<-MSG

SIP/2.0 100 Trying
[last_Via:]
From: <sip:[$remote_addr]>;tag=[$remote_tag]
To: <sip:[$local_addr]>;tag=[call_number]
[last_Call-ID:]
[last_CSeq:]
Server: #{USER_AGENT}
Contact: <sip:[$local_addr];transport=[transport]>
Content-Length: 0
      MSG
      send msg, opts
    end
    alias :send_100 :send_trying

    #
    # Send a "180 Ringing" response
    #
    # @param [Hash] opts A set of options containing SIPp <recv> element attributes
    #
    def send_ringing(opts = {})
      msg = <<-MSG

SIP/2.0 180 Ringing
[last_Via:]
From: <sip:[$remote_addr]>;tag=[$remote_tag]
To: <sip:[$local_addr]>;tag=[call_number]
[last_Call-ID:]
[last_CSeq:]
Server: #{USER_AGENT}
Contact: <sip:[$local_addr];transport=[transport]>
Content-Length: 0
      MSG
      send msg, opts
    end
    alias :send_180 :send_ringing

    #
    # Answer an incoming call
    #
    # @param [Hash] opts A set of options containing SIPp <send> element attributes
    #
    def send_answer(opts = {})
      opts[:retrans] ||= DEFAULT_RETRANS
      msg = <<-MSG

SIP/2.0 200 Ok
[last_Via:]
From: <sip:[$remote_addr]>;tag=[$remote_tag]
To: <sip:[$local_addr]>;tag=[call_number]
[last_Call-ID:]
[last_CSeq:]
Server: #{USER_AGENT}
Contact: <sip:[$local_addr];transport=[transport]>
Content-Type: application/sdp
[routes]
Content-Length: [len]

v=0
o=user1 53655765 2353687637 IN IP[local_ip_type] [local_ip]
s=-
c=IN IP[media_ip_type] [media_ip]
t=0 0
m=audio [media_port] RTP/AVP 0
a=rtpmap:0 PCMU/8000
      MSG
      start_media
      send msg, opts
    end

    #
    # Helper method to answer an INVITE and expect the ACK
    #
    # @param [Hash] opts A set of options containing SIPp element attributes - will be passed to both the <send> and <recv> elements
    #
    def answer(opts = {})
      send_answer opts
      receive_ack opts
    end

    def receive_ack(opts = {})
      recv opts.merge request: 'ACK'
    end

    #
    # Sets an expectation for a SIP 100 message from the remote party
    #
    # @param [Hash] opts A set of options to modify the expectation
    # @option opts [true, false] :optional Whether or not receipt of the message is optional. Defaults to true.
    #
    def receive_trying(opts = {})
      handle_response 100, opts
    end
    alias :receive_100 :receive_trying

    #
    # Sets an expectation for a SIP 180 message from the remote party
    #
    # @param [Hash] opts A set of options to modify the expectation
    # @option opts [true, false] :optional Whether or not receipt of the message is optional. Defaults to true.
    #
    def receive_ringing(opts = {})
      handle_response 180, opts
    end
    alias :receive_180 :receive_ringing

    #
    # Sets an expectation for a SIP 183 message from the remote party
    #
    # @param [Hash] opts A set of options to modify the expectation
    # @option opts [true, false] :optional Whether or not receipt of the message is optional. Defaults to true.
    #
    def receive_progress(opts = {})
      handle_response 183, opts
    end
    alias :receive_183 :receive_progress

    #
    # Sets an expectation for a SIP 200 message from the remote party
    # as well as storing the record set and the response time duration
    #
    # @param [Hash] opts A set of options to modify the expectation
    # @option opts [true, false] :optional Whether or not receipt of the message is optional. Defaults to false.
    #
    def receive_answer(opts = {})
      options = {
        rrs: true, # Record Record Set: Make the Route headers available via [routes] later
        rtd: true # Response Time Duration: Record the response time
      }

      receive_200(options.merge(opts)) do |recv|
        recv << doc.create_element('action') do |action|
          action << doc.create_element('ereg') do |ereg|
            ereg['regexp'] = '<sip:(.*)>.*;tag=([^;]*)'
            ereg['search_in'] = 'hdr'
            ereg['header'] = 'To:'
            ereg['assign_to'] = 'dummy,remote_addr,remote_tag'
          end
        end
      end
      # These variables will only be used if we initiate a hangup
      @reference_variables += %w(dummy remote_addr remote_tag)
    end

    #
    # Sets an expectation for a SIP 200 message from the remote party
    #
    # @param [Hash] opts A set of options to modify the expectation
    # @option opts [true, false] :optional Whether or not receipt of the message is optional. Defaults to false.
    #
    def receive_ok(opts = {}, &block)
      recv({ response: 200 }.merge(opts), &block)
    end
    alias :receive_200 :receive_ok

    #
    # Convenience method to wait for an answer from the called party
    #
    # This sets expectations for optional SIP 100, 180 and 183,
    # followed by a required 200 and sending the acknowledgement.
    #
    # @param [Hash] opts A set of options to modify the expectations
    #
    def wait_for_answer(opts = {})
      receive_trying opts
      receive_ringing opts
      receive_progress opts
      receive_answer opts
      ack_answer opts
    end

    #
    # Acknowledge a received answer message and start media playback
    #
    # @param [Hash] opts A set of options to modify the message parameters
    #
    def ack_answer(opts = {})
      msg = <<-BODY

ACK [next_url] SIP/2.0
Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
From: "#{@from_user}" <sip:#{@from_user}@[local_ip]:[local_port]>;tag=[call_number]
To: <sip:[service]@[remote_ip]:[remote_port]>[peer_tag_param]
Call-ID: [call_id]
CSeq: [cseq] ACK
Contact: <sip:[$local_addr];transport=[transport]>
Max-Forwards: 100
User-Agent: #{USER_AGENT}
Content-Length: 0
[routes]
      BODY
      send msg, opts
      start_media
    end

    #
    # Insert a pause into the scenario and its media of the specified duration
    #
    # @param [Numeric] seconds The duration of the pause in seconds
    #
    def sleep(seconds)
      milliseconds = (seconds.to_f * MSEC).to_i
      pause milliseconds
      @media << "silence:#{milliseconds}" if @media
    end

    #
    # Send DTMF digits
    #
    # @param [String] DTMF digits to send. Must be 0-9, *, # or A-D
    #
    # @example Send a single DTMF digit
    #   send_digits '1'
    #
    # @example Enter a pin number
    #   send_digits '1234'
    #
    def send_digits(digits)
      raise "Media not started" unless @media
      delay = (0.250 * MSEC).to_i # FIXME: Need to pass this down to the media layer
      digits.split('').each do |digit|
        raise ArgumentError, "Invalid DTMF digit requested: #{digit}" unless VALID_DTMF.include? digit

        case @dtmf_mode
        when :rfc2833
          @media << "dtmf:#{digit}"
          @media << "silence:#{delay}"
        when :info
          info = <<-INFO

INFO [next_url] SIP/2.0
Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
From: "#{@from_user}" <sip:#{@from_user}@[local_ip]:[local_port]>;tag=[call_number]
To: <sip:[service]@[remote_ip]:[remote_port]>[peer_tag_param]
Call-ID: [call_id]
CSeq: [cseq] INFO
Contact: <sip:[$local_addr];transport=[transport]>
Max-Forwards: 100
User-Agent: #{USER_AGENT}
[routes]
Content-Length: [len]
Content-Type: application/dtmf-relay

Signal=#{digit}
Duration=#{delay}
          INFO
          send info
          recv response: 200
          pause delay
        end
      end

      if @dtmf_mode == :rfc2833
        pause delay * 2 * digits.size
      end
    end

    #
    # Expect to receive a MESSAGE message
    #
    # @param [String] regexp A regular expression (as a String) to match the message body against
    #
    def receive_message(regexp = nil)
      recv = Nokogiri::XML::Node.new 'recv', doc
      recv['request'] = 'MESSAGE'
      scenario_node << recv

      if regexp
        action = Nokogiri::XML::Node.new 'action', doc
        ereg = Nokogiri::XML::Node.new 'ereg', doc

        ereg['regexp'] = regexp
        ereg['search_in'] = 'body'
        ereg['check_it'] = true

        var = "message_#{@message_variables += 1}"
        ereg['assign_to'] = var
        @reference_variables << var

        action << ereg
        recv << action
      end

      okay
    end

    #
    # Send a BYE message
    #
    # @param [Hash] opts A set of options to modify the message parameters
    #
    def send_bye(opts = {})
      msg = <<-MSG

BYE sip:[$call_addr] SIP/2.0
Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
From: <sip:[$local_addr]>;tag=[call_number]
To: <sip:[$remote_addr]>;tag=[$remote_tag]
Contact: <sip:[$local_addr];transport=[transport]>
Call-ID: [call_id]
CSeq: [cseq] BYE
Max-Forwards: 100
User-Agent: #{USER_AGENT}
Content-Length: 0
[routes]
      MSG
      send msg, opts
    end

    #
    # Expect to receive a BYE message
    #
    # @param [Hash] opts A set of options to modify the expectation
    #
    def receive_bye(opts = {})
      recv opts.merge request: 'BYE'
    end

    #
    # Acknowledge the last request
    #
    # @param [Hash] opts A set of options to modify the message parameters
    #
    def okay(opts = {})
      msg = <<-ACK

SIP/2.0 200 OK
[last_Via:]
[last_From:]
[last_To:]
[last_Call-ID:]
[last_CSeq:]
Contact: <sip:[$local_addr];transport=[transport]>
Max-Forwards: 100
User-Agent: #{USER_AGENT}
Content-Length: 0
[routes]
      ACK
      send msg, opts
    end
    alias :ack_bye :okay

    #
    # Shortcut to set an expectation for a BYE and acknowledge it when received
    #
    # @param [Hash] opts A set of options to modify the expectation
    #
    def wait_for_hangup(opts = {})
      receive_bye(opts)
      ack_bye(opts)
    end

    #
    # Shortcut to send a BYE and wait for the acknowledgement
    #
    # @param [Hash] opts A set of options containing SIPp <recv> element attributes - will be passed to both the <send> and <recv> elements
    #
    def hangup(opts = {})
      send_bye opts
      receive_ok opts
    end

    #
    # Dump the scenario to a SIPp XML string
    #
    # @return [String] the SIPp XML scenario
    def to_xml(options = {})
      pcap_path = options[:pcap_path]
      docdup = doc.dup

      # Not removing in reverse would most likely remove the wrong
      # nodes because of changing indices.
      @media_nodes.reverse.each do |nop|
        nopdup = docdup.xpath(nop.path)

        if pcap_path.nil? or @media.empty?
          nopdup.remove
        else
          exec = nopdup.xpath("./action/exec").first
          exec['play_pcap_audio'] = pcap_path
        end
      end

      unless @reference_variables.empty?
        scenario_node = docdup.xpath('scenario').first
        scenario_node << docdup.create_element('Reference') do |ref|
          ref[:variables] = @reference_variables.to_a.join ','
        end
      end

      docdup.to_xml
    end

    #
    # Compile the scenario and its media to disk
    #
    # Writes the SIPp scenario file to disk at {filename}.xml, and the PCAP media to {filename}.pcap if applicable.
    # {filename} is taken from the :filename option when creating the scenario, or falls back to a down-snake-cased version of the scenario name.
    #
    # @return [String] the path to the resulting scenario file
    #
    # @example Export a scenario to a specified filename
    #   scenario = Scenario.new 'Test Scenario', filename: 'my_scenario'
    #   scenario.compile! # Leaves files at my_scenario.xml and my_scenario.pcap
    #
    # @example Export a scenario to a calculated filename
    #   scenario = Scenario.new 'Test Scenario'
    #   scenario.compile! # Leaves files at test_scenario.xml and test_scenario.pcap
    #
    def compile!
      unless @media.nil?
        print "Compiling media to #{@filename}.pcap..."
        compile_media.to_file filename: "#{@filename}.pcap"
        puts "done."
      end

      scenario_filename = "#{@filename}.xml"
      print "Compiling scenario to #{scenario_filename}..."
      File.open scenario_filename, 'w' do |file|
        file.write to_xml(:pcap_path => "#{@filename}.pcap")
      end
      puts "done."

      scenario_filename
    end

    #
    # Write compiled Scenario XML and PCAP media (if applicable) to tempfiles.
    #
    # These will automatically be closed and deleted once they have gone out of scope, and can be used to execute the scenario without leaving stuff behind.
    #
    # @return [Hash<Symbol => Tempfile>] handles to created Tempfiles at :scenario and :media
    #
    # @see http://www.ruby-doc.org/stdlib-1.9.3/libdoc/tempfile/rdoc/Tempfile.html
    #
    def to_tmpfiles
      unless @media.nil? || @media.empty?
        media_file = Tempfile.new 'media'
        media_file.binmode
        media_file.write compile_media.to_s
        media_file.rewind
      end

      scenario_file = Tempfile.new 'scenario'
      scenario_file.write to_xml(:pcap_path => media_file.try(:path))
      scenario_file.rewind

      {scenario: scenario_file, media: media_file}
    end

  private

    #TODO: SIPS support?
    def parse_user(user)
      user.slice! 0, 4 if user =~ /sip:/
      user = user.split(":")[0]
      user, domain = user.split("@")
      domain ||= "[remote_ip]"
      [user, domain]
    end

    # Split a string into space-delimited components, optionally allowing quoted groups
    # Example: cars "cats and dogs" fish 'hammers' => ["cars", "cats and dogs", "fish", "hammers"]
    def split_quoted_string(args)
      args.to_s.scan(/'.+?'|".+?"|[^ ]+/).map { |s| s.gsub /^['"]|['"]$/, '' }
    end

    def doc
      @doc ||= begin
        Nokogiri::XML::Builder.new do |xml|
          xml.scenario name: @scenario_options[:name] do
            @scenario_node = xml.parent
          end
        end.doc
      end
    end

    def scenario_node
      doc
      @scenario_node
    end

    def parse_args(args)
      if args[:dtmf_mode]
        @dtmf_mode = args[:dtmf_mode].to_sym
        raise ArgumentError, "dtmf_mode must be rfc2833 or info" unless [:rfc2833, :info].include?(@dtmf_mode)
      else
        @dtmf_mode = :rfc2833
      end

      @from_addr, @from_port = args[:source].split ':' if args[:source]
      @to_addr, @to_port = args[:destination].split ':' if args[:destination]
      @from_user = args[:from_user] || "sipp"
    end

    def compile_media
      raise "Media not started" unless @media
      @media.compile!
    end

    def register_message(domain, user)
      <<-BODY

REGISTER sip:#{domain} SIP/2.0
Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
From: <sip:#{user}@#{domain}>;tag=[call_number]
To: <sip:#{user}@#{domain}>
Call-ID: [call_id]
CSeq: [cseq] REGISTER
Contact: <sip:#{@from_user}@[local_ip]:[local_port];transport=[transport]>
Max-Forwards: 10
Expires: 120
User-Agent: #{USER_AGENT}
Content-Length: 0
      BODY
    end

    def register_auth(domain, user, password)
      <<-AUTH

REGISTER sip:#{domain} SIP/2.0
Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
From: <sip:#{user}@#{domain}>;tag=[call_number]
To: <sip:#{user}@#{domain}>
Call-ID: [call_id]
CSeq: [cseq] REGISTER
Contact: <sip:#{@from_user}@[local_ip]:[local_port];transport=[transport]>
Max-Forwards: 20
Expires: 3600
[authentication username=#{user} password=#{password}]
User-Agent: #{USER_AGENT}
Content-Length: 0
      AUTH
    end

    def start_media
      @media = Media.new '127.0.0.255', 55555, '127.255.255.255', 44444
      nop = doc.create_element('nop') { |nop|
        nop << doc.create_element('action') { |action|
          action << doc.create_element('exec')
        }
      }

      @media_nodes << nop
      scenario_node << nop
    end

    def pause(msec)
      pause = Nokogiri::XML::Node.new 'pause', doc
      pause['milliseconds'] = msec.to_i
      scenario_node << pause
    end

    def send(msg, opts = {})
      send = Nokogiri::XML::Node.new 'send', doc
      opts.each do |k,v|
        send[k.to_s] = v
      end
      send << "\n"
      send << Nokogiri::XML::CDATA.new(doc, msg)
      send << "\n" #Newlines are required before and after CDATA so SIPp will parse properly
      yield send if block_given?
      scenario_node << send
    end

    def recv(opts = {}, &block)
      raise ArgumentError, "Receive must include either a response or a request" unless opts.keys.include?(:response) || opts.keys.include?(:request)
      recv = Nokogiri::XML::Node.new 'recv', doc
      opts.each do |k,v|
        recv[k.to_s] = v
      end
      yield recv if block_given?
      scenario_node << recv
    end

    def optional_recv(opts)
      opts[:optional] = true if opts[:optional].nil?
      recv opts
    end

    def handle_response(code, opts)
      optional_recv opts.merge(response: code)
    end
  end
end
