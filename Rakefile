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

desc "Run integration tests against live IRIS instance"
task :integration do
  puts "🧪 Running FileBot integration tests against live IRIS"
  puts "Requires: IRIS Community running, JAR files in vendor/jars/, IRIS_PASSWORD set"
  puts ""
  sh "IRIS_PASSWORD=#{ENV['IRIS_PASSWORD'] || 'passwordpassword'} jruby -Ilib test/iris_integration_test.rb"
end

desc "Run healthcare workflow tests"
task :healthcare do
  puts "🏥 Running healthcare workflow tests"
  sh "IRIS_PASSWORD=#{ENV['IRIS_PASSWORD'] || 'passwordpassword'} jruby -Ilib test/healthcare_workflows_test.rb"
end

desc "Run performance benchmark tests"
task :performance do
  puts "⚡ Running performance benchmark tests"
  sh "IRIS_PASSWORD=#{ENV['IRIS_PASSWORD'] || 'passwordpassword'} jruby -Ilib test/performance_benchmark_test.rb"
end

desc "Run FileMan compatibility tests"
task :compatibility do
  puts "🔄 Running FileMan compatibility tests"
  sh "IRIS_PASSWORD=#{ENV['IRIS_PASSWORD'] || 'passwordpassword'} jruby -Ilib test/fileman_compatibility_test.rb"
end

desc "Run all integration tests (requires live IRIS)"
task :test_integration => [:integration, :healthcare, :performance, :compatibility]

task :default => :test