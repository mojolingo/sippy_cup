# encoding: utf-8
require 'yaml'
require 'sippy_cup/runner'

namespace :sippy_cup do
  desc "Compile the given scenario"
  task :compile, :scenario do |t, args|
    require File.expand_path(args[:scenario])
  end

  desc "Run the scenario described by the given manifest file"
  task :run, :options_file do |t, args|
  	scenario = SippyCup::Scenario.from_manifest File.read(args[:options_file])
    SippyCup::Runner.new(scenario).run
  end
end
