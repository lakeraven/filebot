# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in filebot.gemspec
gemspec

gem "bundler", "~> 2.0"
gem "rake", "~> 13.0"
gem "minitest", "~> 5.0"

group :development do
  gem "rubocop", "~> 1.0"
  gem "rubocop-rails", "~> 2.0"
end

# Platform specific dependencies
platform :jruby do
  # JRuby platform is required for Java Native API integration
  gem "jdbc-postgres" # Example for PostgreSQL if needed
end