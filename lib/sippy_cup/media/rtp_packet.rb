# encoding: utf-8
require 'packetfu'
require 'sippy_cup/media/rtp_header'

module SippyCup
  class Media
    class RTPPacket < PacketFu::UDPPacket
      attr_reader :header

      def initialize(payload_id = 0, marker = false)
        super({})
        @header = RTPHeader.new marker: marker, payload_id: payload_id
        @headers << @header
      end

      def method_missing(method, *args)
        if method.to_s =~ /^rtp_/
          method = method.to_s.sub(/^rtp_/, '').to_sym
          @header.send method, *args
        else
          raise NoMethodError
        end
      end
    end
  end
end
