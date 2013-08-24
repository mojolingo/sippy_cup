ENV['SKIP_RCOV'] = 'true'

group 'rspec' do
  guard 'rspec', :cli => '--format documentation', :all_on_start => true, :all_after_pass => true do
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^lib/(.+)\.rb$})     { |m| "spec/#{m[1]}_spec.rb" }
    watch('spec/spec_helper.rb')  { "spec/" }
  end
end

