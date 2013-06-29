module SippyCup
  class Media
    class PCMUPacket < RTPPacket
      RTP_PAYLOAD_ID = 0x0
      SILENT_BYTE = 0xff.chr
      PTIME = 20 # in milliseconds
      RATE = 8 # in KHz

      def initialize(marker = false)
        super RTP_PAYLOAD_ID, marker
      end

      def media
        SILENT_BYTE * RATE * PTIME
      end
    end
  end
end
