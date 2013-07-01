require 'sippy_cup/media/rtp_payload'

module SippyCup
  class Media
    class PCMUPayload < RTPPayload
      RTP_PAYLOAD_ID = 0x0
      SILENT_BYTE = 0xff.chr
      PTIME = 20 # in milliseconds
      RATE = 8 # in KHz
      attr_accessor :ptime

      def initialize(opts = {})
        super RTP_PAYLOAD_ID
        @ptime = opts[:ptime] || PTIME
        @rate  = opts[:rate]  || RATE
      end

      def media
        SILENT_BYTE * timestamp_interval
      end

      def timestamp_interval
        @rate * @ptime
      end
    end
  end
end
