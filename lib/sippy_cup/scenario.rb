require 'nokogiri'
require 'yaml'
require 'psych'

module SippyCup
  class Scenario
    USER_AGENT = "SIPp/sippy_cup"
    VALID_DTMF = %w{0 1 2 3 4 5 6 7 8 9 0 * # A B C D}.freeze
    MSEC = 1_000

    ##
    # This method will build a scenario based on either a YAML string or a file handle
    # All YAML configuration keys can be overridden by passing in an Hash of corresponding values
    #
    # @param String The YAML to be passed in
    # @param Hash The hash with options to override
    # @return SippyCup::Scenario instance
    #
    def self.from_yaml(yaml, options = {})
      args = ActiveSupport::HashWithIndifferentAccess.new(Psych.safe_load(yaml)).symbolize_keys.merge options

      name = args.delete :name
      steps = args.delete :steps

      scenario = Scenario.new name, args
      scenario.build steps

      scenario
    end

    attr_reader :scenario_options

    def initialize(name, args = {}, &block)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.scenario name: name
      end

      parse_args args

      @scenario_options = args.merge name: name
      @rtcp_port = args[:rtcp_port]
      @filename = args[:filename] || name.downcase.gsub(/\W+/, '_')
      @filename = File.expand_path @filename, Dir.pwd
      @doc = builder.doc
      @media = Media.new '127.0.0.255', 55555, '127.255.255.255', 5060
      @scenario = @doc.xpath('//scenario').first

      instance_eval &block if block_given?
    end

    def parse_args(args)
      raise ArgumentError, "Must include source IP:PORT" unless args.keys.include? :source
      raise ArgumentError, "Must include destination IP:PORT" unless args.keys.include? :destination

      @from_addr, @from_port = args[:source].split ':'
      @to_addr, @to_port = args[:destination].split ':'
      @from_user = args[:from_user] || "sipp"
    end

    ##
    # This method will build the scenario steps provided
    #
    def build(steps)
      raise ArgumentError, "Must provide scenario steps" unless steps
      steps.each do |step|
        instruction, arg = step.split ' ', 2
        if arg && !arg.empty?
          # Strip leading/trailing quotes if present
          arg.gsub!(/^'|^"|'$|"$/, '')
          self.send instruction.to_sym, arg
        else
          self.send instruction
        end
      end
    end

    def compile_media
      @media.compile!
    end

    def sleep(seconds)
      seconds = seconds.to_i
      # TODO play silent audio files to the server to fill the gap
      pause seconds * MSEC
      @media << "silence:#{seconds * MSEC}"
    end

    def invite(opts = {})
      opts[:retrans] ||= 500
      rtp_string = @static_rtcp ? "m=audio #{@rtcp_port.to_i - 1} RTP/AVP 0 101\na=rtcp:#{@rtcp_port}\n" : "m=audio [media_port] RTP/AVP 0 101\n"
      # FIXME: The DTMF mapping (101) is hard-coded. It would be better if we could
      # get this from the DTMF payload generator
      msg = <<-INVITE

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

        v=0
        o=user1 53655765 2353687637 IN IP[local_ip_type] [local_ip]
        s=-
        c=IN IP[media_ip_type] [media_ip]
        t=0 0
        #{rtp_string}
        a=rtpmap:0 PCMU/8000
        a=rtpmap:101 telephone-event/8000
        a=fmtp:101 0-15
      INVITE
      send = new_send msg, opts
      @scenario << send
    end

    def register(user, password = nil, opts = {})
      opts[:retrans] ||= 500
      user, domain = parse_user user
      msg = register_message user, domain: domain
      send = new_send msg, opts
      @scenario << send
      register_auth(user, password, domain: domain) if password
    end

    def register_message(user, opts = {})
      <<-REGISTER

        REGISTER sip:#{opts[:domain]} SIP/2.0
        Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
        From: <sip:#{user}@#{opts[:domain]}>;tag=[call_number]
        To: <sip:#{user}@#{opts[:domain]}>
        Call-ID: [call_id]
        CSeq: [cseq] REGISTER
        Contact: <sip:#{@from_user}@[local_ip]:[local_port];transport=[transport]>
        Max-Forwards: 10
        Expires: 120
        User-Agent: #{USER_AGENT}
        Content-Length: 0
      REGISTER
    end

    def register_auth(user, password, opts = {})
      opts[:retrans] ||= 500
      @scenario << new_recv(response: '401', auth: true, optional: false)
      msg = <<-AUTH

        REGISTER sip:#{opts[:domain]} SIP/2.0
        Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
        From: <sip:#{user}@#{opts[:domain]}>;tag=[call_number]
        To: <sip:#{user}@#{opts[:domain]}>
        Call-ID: [call_id]
        CSeq: [cseq] REGISTER
        Contact: <sip:#{@from_user}@[local_ip]:[local_port];transport=[transport]>
        Max-Forwards: 20
        Expires: 3600
        [authentication username=#{user} password=#{password}]
        User-Agent: #{USER_AGENT}
        Content-Length: 0
      AUTH
      send = new_send msg, opts
      @scenario << send
    end

    def receive_trying(opts = {})
      opts[:optional] = true if opts[:optional].nil?
      opts.merge! response: 100
      @scenario << new_recv(opts)
    end
    alias :receive_100 :receive_trying

    def receive_ringing(opts = {})
      opts[:optional] = true if opts[:optional].nil?
      opts.merge! response: 180
      @scenario << new_recv(opts)
    end
    alias :receive_180 :receive_ringing

    def receive_progress(opts = {})
      opts[:optional] = true if opts[:optional].nil?
      opts.merge! response: 183
      @scenario << new_recv(opts)
    end
    alias :receive_183 :receive_progress

    def receive_answer(opts = {})
      opts.merge! response: 200
      recv = new_recv opts
      # Record Record Set: Make the Route headers available via [route] later
      recv['rrs'] = true
      # Response Time Duration: Record the response time
      recv['rtd'] = true
      @scenario << recv
    end
    alias :receive_200 :receive_answer

    ##
    # Shortcut method that tells SIPp optionally receive
    # SIP 100, 180, and 183 messages, and require a SIP 200 message.
    def wait_for_answer(opts = {})
      receive_trying({optional: true}.merge opts)
      receive_ringing({optional: true}.merge opts)
      receive_progress({optional: true}.merge opts)
      receive_answer opts
    end

    def ack_answer(opts = {})
      msg = <<-ACK

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
      ACK
      @scenario << new_send(msg, opts)
      start_media
    end

    def start_media
      nop = Nokogiri::XML::Node.new 'nop', @doc
      action = Nokogiri::XML::Node.new 'action', @doc
      nop << action
      exec = Nokogiri::XML::Node.new 'exec', @doc
      exec['play_pcap_audio'] = "#{@filename}.pcap"
      action << exec
      @scenario << nop
    end

    ##
    # Send DTMF digits
    # @param[String] DTMF digits to send. Must be 0-9, *, # or A-D
    def send_digits(digits, delay = 0.250)
      delay = 0.250 * MSEC # FIXME: Need to pass this down to the media layer
      digits.split('').each do |digit|
        raise ArgumentError, "Invalid DTMF digit requested: #{digit}" unless VALID_DTMF.include? digit

        @media << "dtmf:#{digit}"
        @media << "silence:#{delay.to_i}"
        pause delay * 2
      end
    end

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
      @scenario << new_send(msg, opts)
    end

    ##
    # Shortcut method that tells SIPp receive a BYE and acknowledge it
    def wait_for_hangup(opts = {})
      receive_bye(opts)
      ack_bye(opts)
    end

    def receive_bye(opts = {})
      opts.merge! request: 'BYE'
      @scenario << new_recv(opts)
    end

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
      @scenario << new_send(msg, opts)
    end

    def to_xml
      @doc.to_xml
    end

    def compile!
      print "Compiling media to #{@filename}.xml..."
      File.open "#{@filename}.xml", 'w' do |file|
        file.write @doc.to_xml
      end
      puts "done."

      print "Compiling scenario to #{@filename}.pcap..."
      compile_media.to_file filename: "#{@filename}.pcap"
      puts "done."
    end

    #TODO: SIPS support?
    def parse_user(user)
      user.slice! 0, 4 if user =~ /sip:/
      user = user.split(":")[0]
      user, domain = user.split("@")
      domain ||= "[remote_ip]"
      [user, domain]
    end

  private

    def pause(msec)
      pause = Nokogiri::XML::Node.new 'pause', @doc
      pause['milliseconds'] = msec.to_i
      @scenario << pause
    end

    def new_send(msg, opts = {})
      send = Nokogiri::XML::Node.new 'send', @doc
      opts.each do |k,v|
        send[k.to_s] = v
      end
      send << "\n"
      send << Nokogiri::XML::CDATA.new(@doc, msg)
      send << "\n" #Newlines are required before and after CDATA so SIPp will parse properly
      send
    end

    def new_recv(opts = {})
      raise ArgumentError, "Receive must include either a response or a request" unless opts.keys.include?(:response) || opts.keys.include?(:request)
      recv = Nokogiri::XML::Node.new 'recv', @doc
      recv['request']  = opts.delete :request  if opts.keys.include? :request
      recv['response'] = opts.delete :response if opts.keys.include? :response
      recv['optional'] = !!opts.delete(:optional)
      opts.each do |k,v|
        recv[k.to_s] = v
      end
      recv
    end
  end
end
