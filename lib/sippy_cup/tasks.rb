require 'yaml'
require 'sippy_cup/runner'

namespace :sippy_cup do
  desc "Compile the given scenario"
  task :compile, :scenario do |t, args|
    require File.expand_path(args[:scenario])
  end

  desc "Run the scenario described by the given YAML file"
  task :run, :options_file do |t, args|
  	options = YAML.load_file args[:options_file]
    SippyCup::Runner.new(options).run
  end
end
