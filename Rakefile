require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "lib"
  t.pattern = "test/**/*_test.rb"
end

desc "Build and install FileBot gem locally"
task :install do
  sh "gem build filebot.gemspec"
  sh "gem install filebot-*.gem"
  sh "rm -f filebot-*.gem"
end

desc "Run FileBot smoke test"
task :smoke_test do
  puts "🧪 Testing FileBot gem functionality"
  ruby_code = <<~RUBY
    require 'filebot'
    puts \"FileBot version: \#{FileBot::VERSION}\"
    puts \"✅ FileBot gem loaded successfully\"
  RUBY
  sh "ruby -e '#{ruby_code}'"
end