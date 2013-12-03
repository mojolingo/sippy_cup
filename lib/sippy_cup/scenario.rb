require 'nokogiri'
require 'psych'
require 'active_support/core_ext/hash'
require 'tempfile'

module SippyCup
  #
  # A representation of a SippyCup scenario from a manifest or created in code. Allows building a scenario from a set of basic primitives, and then exporting to SIPp scenario files, including the XML scenario and PCAP audio.
  #
  class Scenario
    USER_AGENT = "SIPp/sippy_cup"
    VALID_DTMF = %w{0 1 2 3 4 5 6 7 8 9 0 * # A B C D}.freeze
    MSEC = 1_000

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
    # @option options [Integer] :media_port The RTCP (media) port to bind to locally.
    # @option options [String, Numeric] :max_concurrent The maximum number of concurrent calls to execute.
    # @option options [String, Numeric] :number_of_calls The maximum number of calls to execute in the test run.
    # @option options [String, Numeric] :calls_per_second The rate at which to initiate calls.
    # @option options [String] :stats_file The path at which to dump statistics.
    # @option options [String, Numeric] :stats_interval The interval (in seconds) at which to dump statistics (defaults to 1s).
    # @option options [String] :transport_mode The transport mode over which to direct SIP traffic.
    # @option options [String] :scenario_variables A path to a CSV file of variables to be interpolated with the scenario at runtime.
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
      @media = Media.new '127.0.0.255', 55555, '127.255.255.255', 5060
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
          instruction, arg = step.split ' ', 2
          if arg && !arg.empty?
            # Strip leading/trailing quotes if present
            arg.gsub!(/^'|^"|'$|"$/, '')
            self.__send__ instruction, arg
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
      msg = <<-MSG

INVITE sip:[service]@[remote_ip]:[remote_port] SIP/2.0
Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
From: "#{@from_user}" <sip:#{@from_user}@[local_ip]>;tag=[call_number]
To: <sip:[service]@[remote_ip]:[remote_port]>
Call-ID: [call_id]
CSeq: [cseq] INVITE
Contact: <sip:#{@from_user}@[local_ip]:[local_port];transport=[transport]>
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
      send msg, opts
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
      opts[:retrans] ||= 500
      user, domain = parse_user user
      msg = if password
        register_auth domain, user, password
      else
        register_message domain, user
      end
      send msg, opts
    end

    #
    # Sets an expectation for a SIP 100 message from the remote party
    #
    # @param [Hash] opts A set of options to modify the expectation
    # @option opts [true, false] :optional Wether or not receipt of the message is optional. Defaults to true.
    #
    def receive_trying(opts = {})
      handle_response 100, opts
    end
    alias :receive_100 :receive_trying

    #
    # Sets an expectation for a SIP 180 message from the remote party
    #
    # @param [Hash] opts A set of options to modify the expectation
    # @option opts [true, false] :optional Wether or not receipt of the message is optional. Defaults to true.
    #
    def receive_ringing(opts = {})
      handle_response 180, opts
    end
    alias :receive_180 :receive_ringing

    #
    # Sets an expectation for a SIP 183 message from the remote party
    #
    # @param [Hash] opts A set of options to modify the expectation
    # @option opts [true, false] :optional Wether or not receipt of the message is optional. Defaults to true.
    #
    def receive_progress(opts = {})
      handle_response 183, opts
    end
    alias :receive_183 :receive_progress

    #
    # Sets an expectation for a SIP 200 message from the remote party
    #
    # @param [Hash] opts A set of options to modify the expectation
    # @option opts [true, false] :optional Wether or not receipt of the message is optional. Defaults to true.
    #
    def receive_answer(opts = {})
      options = {
        response: 200,
        rrs: true, # Record Record Set: Make the Route headers available via [route] later
        rtd: true # Response Time Duration: Record the response time
      }

      recv options.merge(opts)
    end
    alias :receive_200 :receive_answer

    #
    # Shortcut that sets expectations for optional SIP 100, 180 and 183, followed by a required 200.
    #
    # @param [Hash] opts A set of options to modify the expectations
    #
    def wait_for_answer(opts = {})
      receive_trying({optional: true}.merge opts)
      receive_ringing({optional: true}.merge opts)
      receive_progress({optional: true}.merge opts)
      receive_answer opts
    end

    #
    # Acknowledge a received answer message (SIP 200) and start media playback
    #
    # @param [Hash] opts A set of options to modify the message parameters
    #
    def ack_answer(opts = {})
      msg = <<-BODY

ACK [next_url] SIP/2.0
Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
From: "#{@from_user}" <sip:#{@from_user}@[local_ip]>;tag=[call_number]
[last_To:]
Call-ID: [call_id]
CSeq: [cseq] ACK
Contact: <sip:#{@from_user}@[local_ip]:[local_port];transport=[transport]>
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
      @media << "silence:#{milliseconds}"
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
      delay = (0.250 * MSEC).to_i # FIXME: Need to pass this down to the media layer
      digits.split('').each do |digit|
        raise ArgumentError, "Invalid DTMF digit requested: #{digit}" unless VALID_DTMF.include? digit

        @media << "dtmf:#{digit}"
        @media << "silence:#{delay}"
      end
      pause delay * 2 * digits.size
    end

    #
    # Send a BYE message
    #
    # @param [Hash] opts A set of options to modify the message parameters
    #
    def send_bye(opts = {})
      msg = <<-MSG

BYE [next_url] SIP/2.0
[last_Via:]
From: "#{@from_user}" <sip:#{@from_user}@[local_ip]>;tag=[call_number]
[last_To:]
[last_Call-ID]
CSeq: [cseq] BYE
Contact: <sip:#{@from_user}@[local_ip]:[local_port];transport=[transport]>
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
    # Acknowledge a received BYE message
    #
    # @param [Hash] opts A set of options to modify the message parameters
    #
    def ack_bye(opts = {})
      msg = <<-ACK

SIP/2.0 200 OK
[last_Via:]
[last_From:]
[last_To:]
[last_Call-ID:]
[last_CSeq:]
Contact: <sip:#{@from_user}@[local_ip]:[local_port];transport=[transport]>
Max-Forwards: 100
User-Agent: #{USER_AGENT}
Content-Length: 0
[routes]
      ACK
      send msg, opts
    end

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
    # Dump the scenario to a SIPp XML string
    #
    # @return [String] the SIPp XML scenario
    def to_xml
      doc.to_xml
    end

    #
    # Compile the scenario and its media to disk
    #
    # Writes the SIPp scenario file to disk at {filename}.xml, and the PCAP media to {filename}.pcap.
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
      
      print "Compiling media to #{@filename}.pcap..."
      compile_media.to_file filename: "#{@filename}.pcap"
      puts "done."

      scenario_filename = "#{@filename}.xml"
      print "Compiling scenario to #{scenario_filename}..."
      File.open scenario_filename, 'w' do |file|
        file.write doc.to_xml.gsub(/\{\{PCAP\}\}/, "#{@filename}.pcap")
      end
      puts "done."

      scenario_filename
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
      media_file = Tempfile.new 'media'
      media_file.write compile_media.to_s
      media_file.rewind

      scenario_file = Tempfile.new 'scenario'
      scenario_file.write to_xml.gsub(/\{\{PCAP\}\}/, media_file.path)
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

    def doc
      @doc ||= begin
        Nokogiri::XML::Builder.new do |xml|
          xml.scenario name: @scenario_options[:name]
        end.doc
      end
    end

    def scenario_node
      @scenario_node = doc.xpath('//scenario').first
    end

    def parse_args(args)
      raise ArgumentError, "Must include source IP:PORT" unless args.has_key? :source
      raise ArgumentError, "Must include destination IP:PORT" unless args.has_key? :destination

      @from_addr, @from_port = args[:source].split ':'
      @to_addr, @to_port = args[:destination].split ':'
      @from_user = args[:from_user] || "sipp"
    end

    def compile_media
      @media.compile!
    end

    def register_message(domain, user, opts = {})
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

    def register_auth(domain, user, password, opts = {})
      recv response: '401', auth: true, optional: false
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
      nop = Nokogiri::XML::Node.new 'nop', doc
      action = Nokogiri::XML::Node.new 'action', doc
      nop << action
      exec = Nokogiri::XML::Node.new 'exec', doc
      exec['play_pcap_audio'] = "{{PCAP}}"
      action << exec
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
      scenario_node << send
    end

    def recv(opts = {})
      raise ArgumentError, "Receive must include either a response or a request" unless opts.keys.include?(:response) || opts.keys.include?(:request)
      recv = Nokogiri::XML::Node.new 'recv', doc
      opts.each do |k,v|
        recv[k.to_s] = v
      end
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
