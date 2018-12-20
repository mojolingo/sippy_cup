# encoding: utf-8
require 'spec_helper'

describe SippyCup::Media do
  before :each do
    @from_ip   = '192.168.5.1'
    @from_port = '13579'
    @to_ip     = '192.168.10.2'
    @to_port   = '24680'
    @media = SippyCup::Media.new @from_ip, @from_port, @to_ip, @to_port
  end

  it 'should start with an empty sequence' do
    expect(@media.sequence).to be_empty
  end

  it 'should correctly report itself as empty' do
    expect(@media.empty?).to be true
  end

  it 'should correctly report itself as non-empty' do
    @media << 'silence:1000'
    expect(@media.empty?).to be false
  end

  it 'should append a valid action to the sequence list' do
    @media << 'silence:1000'
    expect(@media.sequence.include?('silence:1000')).to be true
  end

  it 'should raise an error when assigning an invalid action' do
    expect { @media << 'wtfbbq:goat' }.to raise_error
  end

  it 'should produce a PcapFile containing 10 packets for 200ms of silence' do
    @media << 'silence:200'
    pf = @media.compile!
    expect(pf.body.count).to be 10
  end

  it 'should produce a PcapPacket with 20ms of silence at the end' do
    @media << 'silence:20'
    pf = @media.compile!
    packet = pf.body.first
    expect(packet.class).to be PacketFu::PcapPacket
    expect(packet.data[-160, 160]).to eq(0xff.chr * 160)
  end

  it 'should produce a PcapPacket with DTMF digit 3, volume 10 at the end' do
    @media << 'dtmf:3'
    pf = @media.compile!
    packet = pf.body.first
    expect(packet.class).to be PacketFu::PcapPacket
    expect(packet.data[-4, 4]).to eq(['030a00a0'].pack('H*'))
  end

  it 'should produce a PcapPacket with DTMF digit #, volume 10 at the end' do
    @media << 'dtmf:#'
    pf = @media.compile!
    packet = pf.body.first
    expect(packet.class).to be PacketFu::PcapPacket
    expect(packet.data[-4, 4]).to eq(['0b0a00a0'].pack('H*'))
  end

  it 'should generate 15 packets representing a DTMF digit' do
    @media << 'dtmf:1'
    pf = @media.compile!

    expect(pf.body.size).to eq 15
  end

  it 'should not set the end-of-event flag on the first 12 packets representing a DTMF digit' do
    @media << 'dtmf:1'
    pf = @media.compile!

    packets=pf.body.select{|packet| packet.data[-3,1] == ['0a'].pack('H*')}
    expect(packets).to eq pf.body[0..11]
  end

  it 'should set the end-of-event flag on the last 3 packets representing a DTMF digit' do
    @media << 'dtmf:1'
    pf = @media.compile!

    packets=pf.body.select{|packet| packet.data[-3,1] == ['8a'].pack('H*')}
    expect(packets).to eq pf.body[12..14]
  end

  it 'should generate a 250 ms long DTFM event' do
    @media << 'dtmf:1'
    pf = @media.compile!

    start_time = pf.body.first.timestamp.sec.to_f + (0.000001*pf.body.first.timestamp.usec.to_f)
    end_time = pf.body.last.timestamp.sec.to_f + (0.000001*pf.body.last.timestamp.usec.to_f)

    expect(end_time - start_time).to be_within(0.01).of(0.250)
  end

  it 'should generate RTP packets representing 20ms slices of a DTMF digit' do
    @media << 'dtmf:1'
    pf = @media.compile!
    
    expected_durations=
      12.times.map {|i| 160*(i+1)} +  # body of event come in multiples of 160 rtp timestamp units (20ms)
      3.times.map { 160*13 }          # 3 redundant end of event packets 

    expect(pf.body.map{|packet| packet.data[-2,2].unpack('H*')[0].to_i(16)}).to eq expected_durations
  end
  

end
