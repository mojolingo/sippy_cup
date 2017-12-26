# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "sippy_cup/version"

Gem::Specification.new do |s|
  s.name        = "sippy_cup"
  s.version     = SippyCup::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ben Klang", "Will Drexler"]
  s.email       = ["bklang&mojolingo.com", "wdrexler&mojolingo.com"]
  s.homepage    = "https://github.com/bklang/sippy_cup"
  s.summary     = "SIPp profile and RTP stream generator"
  s.description = "This tool makes it easier to generate SIPp load tests with DTMF interactions."
  s.license  = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'packetfu', ["= 1.1.11"] # 1.1.12 introduces a breaking change, removing PacketFu::UDPPacket
  s.add_runtime_dependency 'nokogiri', ["~> 1.8.1"]
  s.add_runtime_dependency 'activesupport', [">= 3.0"]
  s.add_runtime_dependency 'psych', ["~> 2.0.1"] unless RUBY_PLATFORM == 'java'

  s.add_development_dependency 'guard-rspec'
  s.add_development_dependency 'rspec', ["~> 3.4"]
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'simplecov-rcov'
  s.add_development_dependency 'fakefs'
end
