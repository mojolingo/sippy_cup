# encoding: utf-8
require 'packetfu'

module SippyCup
  class Media
    class RTPHeader < Struct.new(:version, :padding, :extension, :marker, :payload_id, :sequence_num, :timestamp, :ssrc_id, :csrc_ids)
      VERSION    = 2

      include StructFu

      def initialize(args = {})
        # TODO: Support Extension Header
        super(
          (args[:version] ? args[:version] : VERSION),
          (args[:padding] ? args[:padding] : 0),
          (args[:extension] ? args[:extension] : 0),
          (args[:marker] ? args[:marker] : 0),
          (args[:payload_id] ? args[:payload_id] : 0),
          Int16.new(args[:sequence_num] ? args[:sequence_num] : 0),
          Int32.new(args[:timestamp] ? args[:timestamp] : 0),
          Int32.new(args[:ssrc_id] ? args[:ssrc_id] : 0),
          (args[:csrc_ids] ? Array(args[:csrc_ids]) : []),
        )
      end

      def read(str)
        self[:version] = str[0].ord >> 6
        self[:padding] = (str[0].ord >> 5) & 1
        self[:extension] = (str[0].ord >> 4) & 1
        num_csrcs = str[0].ord & 0xf
        self[:marker] = str[1] >> 7
        self[:payload_id] = str[1] & 0x7f
        self[:sequence_num].read str[2,2]
        self[:timestamp].read str[4,4]
        self[:ssrc_id].read str[8,4]
        i = 8
        num_csrcs.times do
          self[:csrc_ids] << Int32.new(str[i += 4, 4])
        end
        self[:body] = str[i, str.length - i]
      end

      def csrc_count
        csrc_ids.count
      end

      def csrc_ids_readable
        csrc_ids.to_s
      end

      def to_s
        bytes = [
          (version << 6) + (padding << 5) + (extension << 4) + (csrc_count),
          (marker << 7) + (payload_id),
          sequence_num,
          timestamp,
          ssrc_id
        ].pack 'CCnNN'

        csrc_ids.each do |csrc_id|
          bytes << [csrc_id].pack('N')
        end

        bytes
      end
    end
  end
end

