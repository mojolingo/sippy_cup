# encoding: utf-8
require 'packetfu'
require 'sippy_cup/media/rtp_header'

module SippyCup
  class Media
    class RTPPayload
      attr_reader :header

      def initialize(payload_id = 0, marker = false)
        @header = RTPHeader.new marker: marker, payload_id: payload_id
      end

      def to_bytes
        @header.to_s + media
      end

      def method_missing(method, *args)
        if method.to_s =~ /^rtp_/
          method = method.to_s.sub(/^rtp_/, '').to_sym
          @header.send method, *args
        else
          super
        end
      end
    end
  end
end
