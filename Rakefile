require "bundler/gem_tasks"

desc "Build and install FileBot gem locally"
task :install do
  sh "gem build filebot.gemspec"
  sh "gem install filebot-*.gem"
  sh "rm -f filebot-*.gem"
end

desc "Run community benchmark"
task :benchmark do
  puts "🏥 Running FileBot Community Benchmark"
  puts "Requires: IRIS_PASSWORD environment variable set"
  sh "jruby final_community_benchmark.rb"
end

desc "Run vulnerability stress tests"
task :security do
  puts "🔒 Running FileBot security tests"
  puts "⚠️  WARNING: Only run on test systems!"
  sh "jruby vulnerability_stress_test.rb"
end

desc "Run comprehensive community validation"
task :community => [:benchmark, :security]

task :default => :install