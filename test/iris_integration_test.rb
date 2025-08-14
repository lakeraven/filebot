#!/usr/bin/env jruby

# IRIS Integration Test - Real IRIS database operations
# Requires: Live IRIS instance, IRIS JAR files, IRIS_PASSWORD environment variable
# Usage: IRIS_PASSWORD=passwordpassword jruby -Ilib test/iris_integration_test.rb

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'filebot'
require 'test/unit'

class IRISIntegrationTest < Test::Unit::TestCase
  def setup
    skip_if_no_iris
    @filebot = FileBot.new(:iris)
    @test_dfns = ['9999', '9998', '9997']  # Use high DFNs to avoid conflicts
    cleanup_test_data  # Clean any leftover test data
  end

  def teardown
    cleanup_test_data if @filebot
  end

  def test_iris_connection_works
    assert @filebot.adapter.connected?, "Should be connected to IRIS"
    puts "✅ Connected to IRIS: #{@filebot.adapter.version_info[:database_version]}"
  end

  def test_global_operations_work
    # Test set/get global operations
    test_global = "^FILEBOT"
    test_key = "TEST"
    test_value = "Hello IRIS #{Time.now.to_i}"

    # Set global
    @filebot.adapter.set_global(test_global, test_key, test_value)
    
    # Get global
    result = @filebot.adapter.get_global(test_global, test_key)
    assert_equal test_value, result, "Global set/get should work"

    # Test data global
    data_result = @filebot.adapter.data_global(test_global, test_key)
    assert data_result.to_i > 0, "Data global should return positive value for existing data"

    # Cleanup
    @filebot.adapter.set_global(test_global, test_key, "")
    puts "✅ Global operations working: set/get/data"
  end

  def test_patient_creation_and_retrieval
    test_patient = {
      dfn: @test_dfns[0],
      name: "TESTPATIENT,INTEGRATION", 
      ssn: "555001234",
      dob: "1980-01-01",
      sex: "M"
    }

    # Create patient
    result = @filebot.create_patient(test_patient)
    assert result, "Patient creation should succeed"
    assert result[:success], "Patient creation should return success"
    
    # Retrieve patient demographics
    demographics = @filebot.get_patient_demographics(@test_dfns[0])
    assert demographics, "Should retrieve patient demographics"
    assert_equal "TESTPATIENT,INTEGRATION", demographics[:name], "Patient name should match"
    assert_equal "M", demographics[:sex], "Patient sex should match"

    puts "✅ Patient creation and retrieval working"
  end

  def test_patient_search_functionality
    # Create test patients for search
    test_patients = [
      { dfn: @test_dfns[1], name: "SEARCH,PATIENT1", ssn: "555001235", dob: "1975-05-15", sex: "F" },
      { dfn: @test_dfns[2], name: "SEARCH,PATIENT2", ssn: "555001236", dob: "1990-12-25", sex: "M" }
    ]

    test_patients.each do |patient|
      result = @filebot.create_patient(patient)
      assert result[:success], "Test patient creation should succeed for #{patient[:name]}"
    end

    # Search for patients
    search_results = @filebot.search_patients_by_name("SEARCH")
    assert search_results.is_a?(Array), "Search should return array"
    assert search_results.length >= 2, "Should find at least 2 test patients"

    # Verify search results contain our test patients
    found_names = search_results.map { |p| p[:name] }
    assert found_names.include?("SEARCH,PATIENT1"), "Should find SEARCH,PATIENT1"
    assert found_names.include?("SEARCH,PATIENT2"), "Should find SEARCH,PATIENT2"

    puts "✅ Patient search working: found #{search_results.length} patients"
  end

  def test_batch_operations_performance
    # Create test data
    test_patients = @test_dfns.map.with_index do |dfn, i|
      { dfn: dfn, name: "BATCH,PATIENT#{i+1}", ssn: "55500123#{i}", dob: "198#{i}-01-01", sex: i.even? ? "M" : "F" }
    end

    test_patients.each do |patient|
      @filebot.create_patient(patient)
    end

    # Test batch retrieval
    start_time = Time.now
    batch_results = @filebot.get_patients_batch(@test_dfns)
    end_time = Time.now

    batch_time = (end_time - start_time) * 1000  # Convert to milliseconds

    assert batch_results.is_a?(Array), "Batch results should be array"
    assert_equal @test_dfns.length, batch_results.length, "Should return all requested patients"

    # Verify all patients retrieved correctly
    batch_results.each_with_index do |patient, i|
      assert patient[:name].start_with?("BATCH,PATIENT"), "Patient #{i+1} should have correct name prefix"
    end

    puts "✅ Batch operations working: #{@test_dfns.length} patients in #{batch_time.round(2)}ms"

    # Performance assertion - should be reasonable
    assert batch_time < 5000, "Batch operation should complete in under 5 seconds"
  end

  def test_real_mumps_execution
    # Test direct MUMPS code execution if adapter supports it
    if @filebot.adapter.respond_to?(:execute_mumps)
      # Test simple MUMPS operation
      result = @filebot.adapter.execute_mumps("W $H")
      assert result, "MUMPS execution should return a result"
      puts "✅ MUMPS execution working: $H = #{result}"
    else
      puts "⚠️  MUMPS execution not available (using global operations instead)"
      
      # Test equivalent global operation
      test_result = @filebot.adapter.get_global("^%ZOSF", "OS")
      if test_result
        puts "✅ Global operations working as MUMPS alternative"
      end
    end
  end

  def test_error_handling_with_invalid_data
    # Test invalid DFN
    invalid_demographics = @filebot.get_patient_demographics("99999999")
    assert_nil invalid_demographics, "Invalid DFN should return nil"

    # Test invalid search
    invalid_search = @filebot.search_patients_by_name("NONEXISTENTPATIENTNAME12345")
    assert invalid_search.empty?, "Invalid search should return empty array"

    # Test invalid patient creation
    invalid_patient = { dfn: "", name: "", ssn: "invalid", dob: "invalid", sex: "X" }
    invalid_result = @filebot.create_patient(invalid_patient)
    refute invalid_result[:success], "Invalid patient data should fail validation"

    puts "✅ Error handling working for invalid data"
  end

  def test_concurrent_operations
    # Test that multiple operations can run without interference
    results = []
    
    # Create multiple patients concurrently (simulated)
    @test_dfns.each_with_index do |dfn, i|
      patient = { dfn: dfn, name: "CONCURRENT,TEST#{i+1}", ssn: "55500124#{i}", dob: "198#{i}-01-01", sex: "M" }
      result = @filebot.create_patient(patient)
      results << result
    end

    # Verify all operations succeeded
    assert results.all? { |r| r[:success] }, "All concurrent operations should succeed"

    # Test concurrent retrieval
    retrieved_patients = @test_dfns.map do |dfn|
      @filebot.get_patient_demographics(dfn)
    end

    assert retrieved_patients.all? { |p| p && p[:name].start_with?("CONCURRENT,TEST") }, 
           "All concurrent retrievals should succeed"

    puts "✅ Concurrent operations working: #{results.length} operations completed"
  end

  private

  def skip_if_no_iris
    unless ENV['IRIS_PASSWORD']
      skip "IRIS_PASSWORD not set - skipping integration tests"
    end

    begin
      # Quick connection test
      FileBot::DatabaseAdapterFactory.create_adapter(:iris)
    rescue => e
      skip "IRIS not available: #{e.message}"
    end
  end

  def cleanup_test_data
    return unless @filebot

    @test_dfns.each do |dfn|
      begin
        # Remove patient record
        @filebot.adapter.set_global("^DPT", dfn, "")
        
        # Remove cross-references (attempt common patterns)
        ["^DPT(\"B\")", "^DPT(\"SSN\")", "^DPT(\"BS5\")"].each do |xref|
          # This is a simplified cleanup - real cleanup would iterate through cross-references
          @filebot.adapter.set_global(xref, "TESTPATIENT", dfn, "") rescue nil
          @filebot.adapter.set_global(xref, "SEARCH", dfn, "") rescue nil
          @filebot.adapter.set_global(xref, "BATCH", dfn, "") rescue nil
          @filebot.adapter.set_global(xref, "CONCURRENT", dfn, "") rescue nil
        end
      rescue => e
        # Ignore cleanup errors - test data might not exist
      end
    end

    # Clean test globals
    @filebot.adapter.set_global("^FILEBOT", "TEST", "") rescue nil
  end
end

if __FILE__ == $0
  puts "🧪 FileBot IRIS Integration Test"
  puts "=" * 50
  puts "Testing against live IRIS instance with real MUMPS operations"
  puts "Requires: IRIS Community running, JAR files in vendor/jars/, IRIS_PASSWORD set"
  puts ""
end