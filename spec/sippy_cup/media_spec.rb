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
    @media.sequence.should be_empty
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
    @media.sequence.include?('silence:1000').should be true
  end

  it 'should raise an error when assigning an invalid action' do
    expect { @media << 'wtfbbq:goat' }.to raise_error
  end

  it 'should produce a PcapFile containing 10 packets for 200ms of silence' do
    @media << 'silence:200'
    pf = @media.compile!
    pf.body.count.should be 10
  end

  it 'should produce a PcapPacket with 20ms of silence at the end' do
    @media << 'silence:20'
    pf = @media.compile!
    packet = pf.body.first
    packet.class.should be PacketFu::PcapPacket
    packet.data[-160, 160].should == 0xff.chr * 160
  end

  it 'should produce a PcapPacket with DTMF digit 3, volume 10 at the end' do
    @media << 'dtmf:3'
    pf = @media.compile!
    packet = pf.body.first
    packet.class.should be PacketFu::PcapPacket
    packet.data[-4, 4].should == "\x03\x0a\x00\xa0"
  end

  it 'should produce a PcapPacket with DTMF digit #, volume 10 at the end' do
    @media << 'dtmf:#'
    pf = @media.compile!
    packet = pf.body.first
    packet.class.should be PacketFu::PcapPacket
    packet.data[-4, 4].should == "\x0b\x0a\x00\xa0"
  end
end
