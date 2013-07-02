require 'nokogiri'

module SippyCup
  class Scenario
    VALID_DTMF = %w{0 1 2 3 4 5 6 7 8 9 0 * # A B C D}.freeze
    MSEC = 1_000

    def initialize(name, args = {}, &block)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.scenario name: name
      end

      parse_args args

      @doc = builder.doc
      @media = Media.new @from_addr, @from_port, @to_addr, @to_port
      @scenario = @doc.xpath('//scenario').first

      instance_eval &block
    end

    def parse_args(args)
      raise ArgumentError, "Must include source IP:PORT" unless args.keys.include? :source
      raise ArgumentError, "Must include destination IP:PORT" unless args.keys.include? :destination

      @from_addr, @from_port = args[:source].split ':'
      @to_addr, @to_port = args[:destination].split ':'
    end

    def compile_media
      @media.compile!
    end

    def sleep(seconds)
      # TODO play silent audio files to the server to fill the gap
      pause seconds * MSEC
      @media << "silence:#{seconds * MSEC}"
    end

    def invite
      msg = <<-INVITE

        INVITE sip:[service]@[remote_ip]:[remote_port] SIP/2.0
        Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
        From: sipp <sip:[field0]@[local_ip]>;tag=[call_number]
        To: <sip:[service]@[remote_ip]:[remote_port]>
        Call-ID: [call_id]
        CSeq: [cseq] INVITE
        Contact: sip:[field0]@[local_ip]:[local_port]
        Max-Forwards: 100
        Content-Type: application/sdp
        Content-Length: [len]
  
        v=0
        o=user1 53655765 2353687637 IN IP[local_ip_type] [local_ip]
        s=-
        c=IN IP[media_ip_type] [media_ip]
        t=0 0
        m=audio [media_port] RTP/AVP 0
        a=rtpmap:0 PCMU/8000
      INVITE
      send = new_send msg
      # FIXME: Does this need to be configurable?
      send['retrans'] = 500

      @scenario << send
    end

    def receive_trying(optional = true)
      @scenario.add_child new_recv response: 100, optional: optional
    end
    alias :receive_100 :receive_trying
      
    def receive_ringing(optional = true)
      @scenario.add_child new_recv response: 180, optional: optional
    end
    alias :receive_180 :receive_ringing
      
    def receive_progress(optional = true)
      @scenario.add_child new_recv response: 183, optional: optional
    end
    alias :receive_183 :receive_progress

    def receive_answer
      recv = new_recv response: 200, optional: false
      # Record Record Set: Make the Route headers available via [route] later
      recv['rrs'] = true
      @scenario.add_child recv
    end
    alias :receive_200 :receive_answer

    def ack_answer
      msg = <<-ACK

        ACK [next_url] SIP/2.0
        Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
        From: <sip:[field0]@[local_ip]>;tag=[call_number]
        [last_To:]
        [routes]
        Call-ID: [call_id]
        CSeq: [cseq] ACK
        Contact: sip:[field0]@[local_ip]:[local_port]
        Max-Forwards: 100
        Content-Length: 0
      ACK
      @scenario << new_send(msg)
    end

    ##
    # Send DTMF digits
    # @param[String] DTMF digits to send. Must be 0-9, *, # or A-D
    def send_digits(digits, delay = 0.250)
      delay = 0.250 * MSEC # FIXME: Need to pass this down to the media layer
      digits.split('').each do |digit|
        raise ArgumentError, "Invalid DTMF digit requested: #{digit}" unless VALID_DTMF.include? digit

        @media << "dtmf:#{digit}"
        @media << "silence:#{delay}"
        pause delay * 2
      end
    end


    def receive_bye
      @scenario.add_child new_recv response: 'BYE'
    end

    def ack_bye
      msg = <<-ACK

        SIP/2.0 200 OK
        [last_Via:]
        [last_From:]
        [last_To:]
        [routes]
        [last_Call-ID:]
        [last_CSeq:]
        Contact: <sip:[local_ip]:[local_port];transport=[transport]>
        Max-Forwards: 100
        Content-Length: 0
      ACK
      @scenario << new_send(msg)
    end

    def to_xml
      @doc.to_xml
    end

    def compile!
      # TODO: Write out @doc to a .xml file
      # TODO: Write out the combined silence and DTMF audio to a .pcap file
      raise NotImplementedError
    end

  private
    def pause(msec)
      pause = Nokogiri::XML::Node.new 'pause', @doc
      pause['milliseconds'] = msec.to_i
      @scenario.add_child pause
    end

    def new_send(msg)
      send = Nokogiri::XML::Node.new 'send', @doc
      send << Nokogiri::XML::CDATA.new(@doc, msg)
      send
    end

    def new_recv(opts = {})
      raise ArgumentError, "Receive must include either a response or a request" unless opts.keys.include?(:response) || opts.keys.include?(:request)
      recv = Nokogiri::XML::Node.new 'recv', @doc
      recv['request']  = opts[:request]  if opts.keys.include? :request
      recv['response'] = opts[:response] if opts.keys.include? :response
      recv['optional'] = !!opts[:optional]
      recv
    end
  end

end

