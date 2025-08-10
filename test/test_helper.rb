# frozen_string_literal: true

# FileBot Test Helper - JRuby unit testing support for FileBot system
require "java"

# Import IRIS Native API for JRuby testing
java_import "com.intersystems.jdbc.IRISConnection"
java_import "com.intersystems.jdbc.IRISDataSource"

module FileBotTestHelper
  # ...existing code for all your mock classes and helpers...
end

# Test configuration and helpers
module ActiveSupport
  class TestCase
    include FileBotTestHelper

    # JRuby-specific test setup
    def setup_jruby_environment
      skip "JRuby required for FileBot tests" unless RUBY_PLATFORM == "java"
    end

    # IRIS database test helpers
    def setup_iris_test_connection
      return nil unless iris_available_for_testing?

      datasource = IRISDataSource.new
      datasource.setURL("jdbc:IRIS://localhost:1972/USER")
      datasource.setUser("_SYSTEM")
      datasource.setPassword("passwordpassword")
      datasource.getConnection
    rescue => e
      puts "IRIS test connection failed: #{e.message}"
      nil
    end

    def iris_available_for_testing?
      # Check if IRIS is running for integration tests
      begin
        setup_iris_test_connection&.close
        true
      rescue
        false
      end
    end

    # ...existing code for all your mock factory methods, test data, and assertion helpers...
  end
end

# Global constants for FileBot testing
FILEBOT_TEST_FILES = {
  patient_file: 2,
  provider_file: 200,
  medication_file: 52,
  lab_file: 63
}.freeze

FILEBOT_MOCK_GLOBALS = {
  2 => "DPT",
  200 => "VA",
  52 => "PS",
  63 => "LAB"
}.freeze

# Optional: Log test helper loaded
puts "FileBot Test Helper loaded - JRuby: #{RUBY_PLATFORM == 'java'}, IRIS Available: #{defined?(Test::Unit::TestCase) && Test::Unit::TestCase.new.iris_available_for_testing?}"