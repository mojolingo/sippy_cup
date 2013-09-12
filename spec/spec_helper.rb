# encoding: utf-8

%w{
  sippy_cup
}.each { |f| require f }

RSpec.configure do |config|
  config.mock_framework = :rspec
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
  config.color_enabled = true
end
