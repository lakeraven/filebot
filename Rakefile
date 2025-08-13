require "bundler/gem_tasks"
require "rake/testtask"

# Standard gem tests (no database dependencies required)
Rake::TestTask.new(:test) do |t|
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

desc "Validate gem architecture and functionality"
task :validate do
  puts "🎯 Running FileBot gem validation"
  sh "jruby -Ilib test/gem_validation.rb"
end

desc "Run core functionality tests"
task :gem_test do
  puts "🔍 Running core functionality tests"
  sh "jruby -Ilib test/simple_test.rb"
  puts "\n📊 Running adapter tests"
  sh "jruby -Ilib test/simple_adapter_test.rb"
end

desc "Build and install FileBot gem locally"
task :install do
  sh "gem build filebot.gemspec"
  sh "gem install filebot-*.gem"
  sh "rm -f filebot-*.gem"
end

task :default => :test