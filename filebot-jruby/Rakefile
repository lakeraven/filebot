# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

Rails.application.load_tasks

# FileBot gem tasks
begin
  require "bundler/gem_tasks"
  require "rake/testtask"
  require "standard/rake"

  Rake::TestTask.new(:filebot_test) do |t|
    t.libs << "test"
    t.libs << "lib"
    t.test_files = FileList["test/filebot/**/*_test.rb"]
  end

  namespace :filebot do
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
        puts "FileBot version: \#{FileBot::VERSION}"
        puts "✅ FileBot gem loaded successfully"
      RUBY
      sh "ruby -e '#{ruby_code}'"
    end
  end
rescue LoadError
  # Gem tasks not available in production
end
