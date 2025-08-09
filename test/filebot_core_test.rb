# frozen_string_literal: true

require "test_helper"
require "java"

# Import IRIS Native API
java_import "com.intersystems.jdbc.IRISConnection"
java_import "com.intersystems.jdbc.IRISDataSource"

class FileBotCoreTest < ActiveSupport::TestCase
  def setup
    @filebot = FileBot.instance
    @test_patient_data = {
      "0.01" => "TESTPATIENT,UNIT",
      "0.02" => "M",
      "0.03" => "2850505",
      "0.09" => "123456789",
      "0.11" => "123 TEST STREET",
      "0.111" => "TEST CITY",
      "0.112" => "CA",
      "0.113" => "90210",
      "0.131" => "555-1234"
    }
  end

  def teardown
    # Clean up test data
    cleanup_test_records
  end

  test "FileBot singleton initialization" do
    assert_not_nil @filebot
    assert_instance_of FileBot, @filebot
    assert_same @filebot, FileBot.instance
  end

  test "IRIS connection setup" do
    assert_not_nil @filebot.instance_variable_get(:@iris)
    assert_not_nil @filebot.instance_variable_get(:@data_dictionary)
    assert_not_nil @filebot.instance_variable_get(:@validator)
    assert_not_nil @filebot.instance_variable_get(:@cross_refs)
    assert_not_nil @filebot.instance_variable_get(:@security)
  end

  test "gets method with valid patient data" do
    # Create test patient first
    result = @filebot.file_new(2, @test_patient_data)
    assert result[:success], "Failed to create test patient: #{result[:errors]}"
    
    dfn = result[:iens]
    
    # Test GETS equivalent
    patient_data = @filebot.gets(2, "#{dfn},", ".01;.02;.03;.09")
    
    assert_not_nil patient_data
    assert patient_data.success?
    assert_equal "TESTPATIENT,UNIT", patient_data.data[".01"]
    assert_equal "M", patient_data.data[".02"]
    assert_equal "2850505", patient_data.data[".03"]
    assert_equal "123456789", patient_data.data[".09"]
  end

  test "gets method with invalid DFN" do
    patient_data = @filebot.gets(2, "999999,", ".01;.02")
    
    assert_not_nil patient_data
    refute patient_data.success?
    assert_includes patient_data.errors, "Patient not found"
  end

  test "gets method with security access denied" do
    # Mock security manager to deny access
    security_mock = Minitest::Mock.new
    security_mock.expect(:can_read?, false, [Object, Integer, String])
    @filebot.instance_variable_set(:@security, security_mock)
    
    assert_raises FileBotSecurityError do
      @filebot.gets(2, "1,", ".01")
    end
    
    security_mock.verify
  end

  test "file_new method creates new patient record" do
    result = @filebot.file_new(2, @test_patient_data)
    
    assert result[:success], "Registration failed: #{result[:errors]}"
    assert_not_nil result[:iens]
    assert result[:iens] > 0
    assert_equal "Patient registered successfully", result[:record][:message]
  end

  test "file_new method validation failure" do
    invalid_data = {
      "0.01" => "", # Required field missing
      "0.02" => "X", # Invalid gender
      "0.03" => "9999999" # Invalid date
    }
    
    result = @filebot.file_new(2, invalid_data)
    
    refute result[:success]
    assert_not_empty result[:errors]
    assert_includes result[:errors].join, "Name required"
  end

  test "update method with valid changes" do
    # Create test patient
    create_result = @filebot.file_new(2, @test_patient_data)
    dfn = create_result[:iens]
    
    # Update patient data
    changes = {
      "0.01" => "UPDATED,PATIENT",
      "0.131" => "555-9999"
    }
    
    result = @filebot.update(2, "#{dfn},", changes)
    
    assert result.success?, "Update failed: #{result.errors}"
    
    # Verify changes were applied
    updated_data = @filebot.gets(2, "#{dfn},", ".01;.131")
    assert_equal "UPDATED,PATIENT", updated_data.data[".01"]
    assert_equal "555-9999", updated_data.data[".131"]
  end

  test "update method with invalid DFN" do
    changes = { "0.01" => "INVALID,UPDATE" }
    
    result = @filebot.update(2, "999999,", changes)
    
    refute result.success?
    assert_includes result.errors, "Patient not found"
  end

  test "transaction rollback on error" do
    # Mock a scenario where update fails mid-transaction
    original_method = @filebot.method(:update_main_record)
    
    @filebot.define_singleton_method(:update_main_record) do |*args|
      raise StandardError, "Simulated database error"
    end
    
    begin
      result = @filebot.update(2, "1,", { "0.01" => "SHOULD,FAIL" })
      refute result.success?
    ensure
      # Restore original method
      @filebot.define_singleton_method(:update_main_record, original_method)
    end
  end

  test "security logging for all operations" do
    security_mock = Minitest::Mock.new
    security_mock.expect(:can_read?, true, [Object, Integer, String])
    security_mock.expect(:log_access, nil, [Object, Integer, String, String, Array])
    
    @filebot.instance_variable_set(:@security, security_mock)
    
    @filebot.gets(2, "1,", ".01")
    
    security_mock.verify
  end

  private

  def cleanup_test_records
    # Clean up any test records created during tests
    # This would typically involve removing test data from IRIS
    test_names = ["TESTPATIENT,UNIT", "UPDATED,PATIENT"]
    
    test_names.each do |name|
      # Implementation would remove test records from ^DPT global
      # @filebot.delete_test_record(name) if exists
    end
  end
end