require 'pcap'

module SippyCup
  class RTPGenerator
    DEFAULT_DATALINK = 1 # Corresponds to DLT_EN10MB, Ethernet (10Mb) from pcap/bpf.h

    def initialize
      @output = Pcap::Capture.open_dead DEFAULT_DATALINK, 65535



    def save!(file)
      pcap_file = Pcap::Dumper.open @output, file
      @output.loop(-1) do |packet|
        pcap_file.dump packet
      end
    end
  end
end
