require 'ipaddr'
require 'sippy_cup/media/pcmu_payload'
require 'sippy_cup/media/dtmf_payload'

module SippyCup
  class Media
    VALID_STEPS = %w{silence dtmf}.freeze
    attr_accessor :sequence
    attr_reader :packets

    def initialize(from_addr, from_port, to_addr, to_port, generator = PCMUPayload)
      @from_addr, @to_addr = IPAddr.new(from_addr), IPAddr.new(to_addr)
      @from_port, @to_port, @generator = from_port, to_port, generator
      reset!
    end

    def reset!
      @sequence = []
      @packets = []
    end

    def <<(input)
      get_step input # validation
      @sequence << input
    end

    def compile!
      sequence_number = 0
      timestamp = 0
      ssrc_id = rand 2147483648

      @sequence.each do |input|
        action, value = get_step input
        
        case action
        when 'silence'
          # value is the duration in milliseconds
          # append that many milliseconds of silent RTP audio
          (value.to_i / @generator::PTIME).times do
            packet = new_packet
            rtp_frame = @generator.new
            rtp_frame.rtp_timestamp = timestamp += rtp_frame.timestamp_interval
            rtp_frame.rtp_sequence_num = sequence_number += 1
            rtp_frame.rtp_ssrc_id = ssrc_id
            packet.headers.last.body = rtp_frame.to_bytes
            packet.recalc
            @packets << packet
          end
        when 'dtmf'
          # value is the DTMF digit to send
          # append that RFC2833 digit
          # Assume 0.5 second duration for now
          count = 500 / DTMFPayload::PTIME
          count.times do |i|
            packet = new_packet
            dtmf_frame = DTMFPayload.new value
            dtmf_frame.rtp_marker = 1 if i == 0
            dtmf_frame.rtp_timestamp = timestamp # Is this correct? This is what Blink does...
            dtmf_frame.rtp_sequence_num = sequence_number += 1
            dtmf_frame.rtp_ssrc_id = ssrc_id
            dtmf_frame.end_of_event = (count == i) # Last packet?
            packet.headers.last.body = dtmf_frame.to_bytes
            packet.recalc
            @packets << packet
          end
          # Now bump up the timestamp to cover the gap
          timestamp += count * DTMFPayload::TIMESTAMP_INTERVAL
        else
        end
      end
    end
  private
    def get_step(input)
      action, value = input.split ':'
      raise "Invalid Sequence: #{input}" unless VALID_STEPS.include? action

      [action, value]
    end

    def new_packet
      packet = PacketFu::UDPPacket.new
      packet.ip_src = @from_addr.to_i
      packet.ip_dst = @to_addr.to_i
      packet.udp_src = @from_port
      packet.udp_dst = @to_port
      packet
    end
  end
end
