require 'sippy_cup/media/rtp_payload'

module SippyCup
  class Media
    class DTMFPayload < RTPPayload
      RTP_PAYLOAD_ID = 101
      PTIME = 20 # in milliseconds
      TIMESTAMP_INTERVAL = 160
      END_OF_EVENT = 1 << 7
      DTMF = %w{0 1 2 3 4 5 6 7 8 9 * # A B C D}.freeze
      attr_accessor :ptime

      def initialize(digit, opts = {})
        super RTP_PAYLOAD_ID
        @flags = 0
        @digit = atoi digit
        @ptime = opts[:ptime] || PTIME

        volume opts[:volume] || 10
      end

      def end_of_event=(bool)
        if bool
          @flags |= END_OF_EVENT
        else
          @flags &= (0xf - END_OF_EVENT)
        end
      end

      def atoi(digit)
        DTMF.index digit.to_s
      end

      def volume(value)
        value = [value, 0x3f].min # Cap to 6 bits
        @flags &= 0xc0 # zero out old volume
        @flags += value
      end

      def end_of_event
        @flags & END_OF_EVENT
      end

      def media
        [@digit, @flags, timestamp_interval].pack 'CCn'
      end

      def timestamp_interval
        TIMESTAMP_INTERVAL
      end
    end
  end
end

