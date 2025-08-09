# frozen_string_literal: true

require "test_helper"
require "java"

# Import IRIS Native API for integration testing
java_import "com.intersystems.jdbc.IRISConnection"
java_import "com.intersystems.jdbc.IRISDataSource"

class FileBotIntegrationTest < ActiveSupport::TestCase
  def setup
    # Skip integration tests if IRIS is not available
    skip "IRIS database not available" unless iris_available?
    
    @filebot = FileBot.instance
    @test_data_cleanup = []
  end

  def teardown
    # Clean up test data
    cleanup_test_data
  end

  test "end_to_end_patient_lifecycle" do
    # Complete patient lifecycle test
    patient_data = {
      "0.01" => "INTEGRATION,TESTPATIENT",
      "0.02" => "M",
      "0.03" => "1985-05-15", 
      "0.09" => "555667777",
      "0.11" => "123 INTEGRATION STREET",
      "0.111" => "TEST CITY",
      "0.112" => "CA", 
      "0.113" => "90210",
      "0.131" => "555-TEST"
    }

    # 1. Create patient
    creation_result = @filebot.file_new(2, patient_data)
    assert creation_result[:success], "Patient creation failed: #{creation_result[:errors]}"
    
    dfn = creation_result[:iens]
    @test_data_cleanup << { type: :patient, dfn: dfn }
    
    # 2. Retrieve patient data
    retrieval_result = @filebot.gets(2, "#{dfn},", ".01;.02;.03;.09;.11;.111;.112;.113;.131")
    assert retrieval_result.success?, "Patient retrieval failed: #{retrieval_result.errors}"
    
    # Verify all fields were stored and retrieved correctly
    data = retrieval_result.data
    assert_equal "INTEGRATION,TESTPATIENT", data[".01"]
    assert_equal "M", data[".02"]
    assert_equal "1985-05-15", data[".03"]
    assert_equal "555667777", data[".09"]
    assert_equal "123 INTEGRATION STREET", data[".11"]
    assert_equal "TEST CITY", data[".111"]
    assert_equal "CA", data[".112"]
    assert_equal "90210", data[".113"]
    assert_equal "555-TEST", data[".131"]

    # 3. Update patient data
    updates = {
      ".01" => "UPDATED,TESTPATIENT",
      ".131" => "555-UPDATED"
    }
    
    update_result = @filebot.update(2, "#{dfn},", updates)
    assert update_result.success?, "Patient update failed: #{update_result.errors}"

    # 4. Verify updates were applied
    updated_data = @filebot.gets(2, "#{dfn},", ".01;.131")
    assert_equal "UPDATED,TESTPATIENT", updated_data.data[".01"]
    assert_equal "555-UPDATED", updated_data.data[".131"]
  end

  test "cross_reference_functionality" do
    # Test that cross-references are properly maintained
    patient_name = "XREF,TESTPATIENT"
    patient_ssn = "888669999"
    
    patient_data = {
      "0.01" => patient_name,
      "0.02" => "F",
      "0.03" => "1990-01-01",
      "0.09" => patient_ssn
    }

    creation_result = @filebot.file_new(2, patient_data)
    assert creation_result[:success]
    
    dfn = creation_result[:iens]
    @test_data_cleanup << { type: :patient, dfn: dfn }

    # Test B cross-reference (name lookup)
    # This would require direct IRIS global inspection
    iris_connection = setup_direct_iris_connection
    iris_global = iris_connection.createIRIS
    
    # Check if B cross-reference exists
    b_xref_exists = iris_global.isDefined("DPT", "B", patient_name.upcase, dfn)
    assert b_xref_exists, "B cross-reference not created for patient name"

    # Check SSN cross-reference if implemented
    ssn_xref_exists = iris_global.isDefined("DPT", "SSN", patient_ssn, dfn)
    assert ssn_xref_exists, "SSN cross-reference not created"
    
    iris_connection.close
  end

  test "validation_enforcement" do
    # Test that validation rules are properly enforced
    invalid_patients = [
      {
        data: { "0.01" => "", "0.02" => "M" }, # Missing required name
        expected_error: "Name required"
      },
      {
        data: { "0.01" => "VALID,NAME", "0.02" => "X" }, # Invalid gender
        expected_error: "Invalid value for SEX"
      },
      {
        data: { "0.01" => "VALID,NAME", "0.03" => "invalid-date" }, # Invalid date
        expected_error: "Invalid date format"
      },
      {
        data: { "0.01" => "VALID,NAME", "0.09" => "invalid-ssn" }, # Invalid SSN
        expected_error: "Invalid SSN format"
      }
    ]

    invalid_patients.each do |test_case|
      result = @filebot.file_new(2, test_case[:data])
      refute result[:success], "Expected validation to fail for: #{test_case[:data]}"
      assert_includes result[:errors].join, test_case[:expected_error]
    end
  end

  test "concurrent_access_handling" do
    # Test concurrent access to the same patient record
    patient_data = {
      "0.01" => "CONCURRENT,TEST",
      "0.02" => "M",
      "0.03" => "1985-01-01",
      "0.09" => "777888999"
    }

    creation_result = @filebot.file_new(2, patient_data)
    dfn = creation_result[:iens]
    @test_data_cleanup << { type: :patient, dfn: dfn }

    # Simulate concurrent updates
    threads = []
    results = []
    
    5.times do |i|
      threads << Thread.new do
        update_data = { ".131" => "555-#{i}#{i}#{i}#{i}" }
        result = @filebot.update(2, "#{dfn},", update_data)
        results << result
      end
    end

    threads.each(&:join)

    # All updates should succeed (last one wins)
    assert results.all?(&:success?), "Some concurrent updates failed"

    # Verify final state is consistent
    final_data = @filebot.gets(2, "#{dfn},", ".131")
    assert_match(/555-\d{4}/, final_data.data[".131"])
  end

  test "transaction_rollback_on_error" do
    # Test that transactions properly roll back on errors
    patient_data = {
      "0.01" => "ROLLBACK,TEST",
      "0.02" => "M", 
      "0.03" => "1985-01-01",
      "0.09" => "666777888"
    }

    creation_result = @filebot.file_new(2, patient_data)
    dfn = creation_result[:iens]
    @test_data_cleanup << { type: :patient, dfn: dfn }

    # Attempt update with invalid data that should cause rollback
    invalid_updates = {
      ".01" => "VALID,UPDATE",
      ".02" => "INVALID_GENDER", # This should cause validation failure
      ".09" => "ALSO_VALID_SSN"
    }

    update_result = @filebot.update(2, "#{dfn},", invalid_updates)
    refute update_result.success?

    # Verify that NO changes were applied (transaction rolled back)
    current_data = @filebot.gets(2, "#{dfn},", ".01;.02;.09")
    assert_equal "ROLLBACK,TEST", current_data.data[".01"] # Should be unchanged
    assert_equal "M", current_data.data[".02"] # Should be unchanged
    assert_equal "666777888", current_data.data[".09"] # Should be unchanged
  end

  test "performance_benchmarks" do
    # Performance benchmark tests
    patient_data = {
      "0.01" => "PERFORMANCE,TEST",
      "0.02" => "F",
      "0.03" => "1990-01-01",
      "0.09" => "111222333"
    }

    # Benchmark patient creation
    creation_start = Time.current
    creation_result = @filebot.file_new(2, patient_data)
    creation_duration = Time.current - creation_start
    
    assert creation_result[:success]
    assert creation_duration < 1.0, "Patient creation too slow: #{creation_duration}s"
    
    dfn = creation_result[:iens]
    @test_data_cleanup << { type: :patient, dfn: dfn }

    # Benchmark patient retrieval
    retrieval_start = Time.current
    retrieval_result = @filebot.gets(2, "#{dfn},", ".01;.02;.03;.09")
    retrieval_duration = Time.current - retrieval_start
    
    assert retrieval_result.success?
    assert retrieval_duration < 0.5, "Patient retrieval too slow: #{retrieval_duration}s"

    # Benchmark patient update
    update_start = Time.current
    update_result = @filebot.update(2, "#{dfn},", { ".131" => "555-PERF" })
    update_duration = Time.current - update_start
    
    assert update_result.success?
    assert update_duration < 0.5, "Patient update too slow: #{update_duration}s"
  end

  test "security_access_control" do
    # Test security and access control
    # This would require mocking or setting up different user contexts
    
    # Create test patient
    patient_data = {
      "0.01" => "SECURITY,TEST",
      "0.02" => "M",
      "0.03" => "1985-01-01"
    }

    creation_result = @filebot.file_new(2, patient_data)
    dfn = creation_result[:iens]
    @test_data_cleanup << { type: :patient, dfn: dfn }

    # Test access with valid permissions (should succeed)
    retrieval_result = @filebot.gets(2, "#{dfn},", ".01;.02")
    assert retrieval_result.success?

    # Test access control logging
    # Verify that access was logged for HIPAA compliance
    # This would check audit tables/globals in a real implementation
  end

  test "healthcare_specific_validations" do
    # Test healthcare-specific validation rules
    test_cases = [
      {
        description: "Prohibited test patient name",
        data: { "0.01" => "TEST,PATIENT", "0.02" => "M" },
        should_fail: true
      },
      {
        description: "Adult patient consent validation",
        data: { 
          "0.01" => "ADULT,PATIENT", 
          "0.03" => "1980-01-01", # Adult
          "consent_flag" => "N" # No consent
        },
        should_fail: true
      },
      {
        description: "Veteran without service number", 
        data: {
          "0.01" => "VETERAN,PATIENT",
          "veteran_flag" => "Y",
          "service_number" => "" # Missing
        },
        should_fail: true
      }
    ]

    test_cases.each do |test_case|
      result = @filebot.file_new(2, test_case[:data])
      
      if test_case[:should_fail]
        refute result[:success], "#{test_case[:description]} should have failed validation"
      else
        assert result[:success], "#{test_case[:description]} should have passed validation"
        @test_data_cleanup << { type: :patient, dfn: result[:iens] }
      end
    end
  end

  private

  def iris_available?
    # Check if IRIS database is available for integration testing
    begin
      datasource = IRISDataSource.new
      datasource.setURL("jdbc:IRIS://localhost:1972/USER")
      datasource.setUser("_SYSTEM")
      datasource.setPassword("passwordpassword")
      
      connection = datasource.getConnection
      connection.close
      true
    rescue => e
      Rails.logger.warn "IRIS not available for integration tests: #{e.message}"
      false
    end
  end

  def setup_direct_iris_connection
    datasource = IRISDataSource.new
    datasource.setURL("jdbc:IRIS://localhost:1972/USER")
    datasource.setUser("_SYSTEM") 
    datasource.setPassword("passwordpassword")
    datasource.getConnection
  end

  def cleanup_test_data
    return unless iris_available?
    
    @test_data_cleanup.each do |cleanup_item|
      begin
        case cleanup_item[:type]
        when :patient
          # Remove test patient from IRIS
          # This would use direct IRIS commands to clean up
          # KILL ^DPT(dfn), cross-references, etc.
        end
      rescue => e
        Rails.logger.warn "Failed to cleanup test data: #{e.message}"
      end
    end
  end
end