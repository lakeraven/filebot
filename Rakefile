require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList[
    "test/simple_test.rb",
    "test/simple_adapter_test.rb",
    "test/api_completeness_test.rb",
    "test/final_structure_test.rb",
    "test/test_structure_check.rb"
  ]
  t.verbose = true
end

# Gem-specific test task that doesn't require database connections
Rake::TestTask.new(:gem_test) do |t|
  t.libs << "test" 
  t.libs << "lib"
  t.test_files = FileList[
    "test/simple_test.rb",
    "test/simple_adapter_test.rb", 
    "test/final_structure_test.rb",
    "test/gem_integration_test.rb"
  ]
  t.verbose = true
  t.ruby_opts = ['-w']
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

desc "Validate FileBot gem architecture and refactoring"
task :validate do
  puts "🎯 Running FileBot architectural validation"
  sh "jruby -Ilib test/gem_validation.rb"
end

desc "Run gem-targeted tests (no database dependencies)"
task :gem_validate do
  puts "🔍 Running gem validation and core tests"
  sh "jruby -Ilib test/gem_validation.rb"
  puts "\n📋 Running simple structure tests"
  sh "jruby -Ilib test/simple_test.rb"
end