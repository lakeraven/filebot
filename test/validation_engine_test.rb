# frozen_string_literal: true

require "test_helper"

class ValidationEngineTest < ActiveSupport::TestCase
  def setup
    @data_dictionary = setup_mock_data_dictionary
    @validation_engine = ValidationEngine.new(@data_dictionary)
    
    @valid_patient_data = {
      "0.01" => "SMITH,JOHN",
      "0.02" => "M", 
      "0.03" => "1985-05-15",
      "0.09" => "123456789"
    }
  end

  test "validate_new_record with valid data" do
    result = @validation_engine.validate_new_record(2, @valid_patient_data)
    
    assert result.success?, "Validation should succeed: #{result.errors}"
    assert_empty result.errors
  end

  test "validate_new_record with invalid field data" do
    invalid_data = @valid_patient_data.merge({
      "0.01" => "", # Required field missing
      "0.02" => "X", # Invalid gender
      "0.03" => "invalid-date" # Invalid date format
    })
    
    result = @validation_engine.validate_new_record(2, invalid_data)
    
    refute result.success?
    assert result.errors.length >= 3
    assert_includes result.errors.join, "required"
    assert_includes result.errors.join, "Invalid"
  end

  test "validate_new_record with healthcare validator errors" do
    # Test data that passes field validation but fails healthcare rules
    test_data = @valid_patient_data.merge({
      "0.01" => "TEST,PATIENT" # Prohibited test patient name
    })
    
    result = @validation_engine.validate_new_record(2, test_data)
    
    refute result.success?
    assert_includes result.errors.join, "Test patient name not allowed"
  end

  test "validate_new_record with business rules violations" do
    # Adult patient without consent
    adult_data = @valid_patient_data.merge({
      "0.03" => "1980-01-01", # Adult DOB
      "consent_flag" => "N"    # No consent
    })
    
    result = @validation_engine.validate_new_record(2, adult_data)
    
    refute result.success?
    assert_includes result.errors.join, "Adult patient must have consent"
  end

  test "validate_new_record with veteran business rules" do
    veteran_data = @valid_patient_data.merge({
      "veteran_flag" => "Y",
      "service_number" => "" # Missing service number
    })
    
    result = @validation_engine.validate_new_record(2, veteran_data)
    
    refute result.success?
    assert_includes result.errors.join, "Veteran patients must have service number"
  end

  test "validate_update_record with changes" do
    changes = {
      "0.01" => "UPDATED,NAME",
      "0.131" => "555-1234" # Phone number
    }
    
    result = @validation_engine.validate_update_record(2, "123,", changes)
    
    assert result.success?, "Update validation should succeed: #{result.errors}"
  end

  test "validate_update_record with invalid changes" do
    invalid_changes = {
      "0.01" => "", # Can't clear required field
      "0.09" => "invalid-ssn" # Invalid SSN format
    }
    
    result = @validation_engine.validate_update_record(2, "123,", invalid_changes)
    
    refute result.success?
    assert result.errors.length >= 2
  end

  test "healthcare validator integration" do
    healthcare_validator = @validation_engine.instance_variable_get(:@healthcare_validator)
    
    # Test patient name validation
    result = healthcare_validator.validate_field(2, "0.01", "VALID,PATIENT")
    assert result.success?
    
    result = healthcare_validator.validate_field(2, "0.01", "")
    refute result.success?
    assert_includes result.error_message, "Name required"
    
    # Test SSN validation
    result = healthcare_validator.validate_field(2, "0.09", "123456789")
    assert result.success?
    
    result = healthcare_validator.validate_field(2, "0.09", "invalid")
    refute result.success?
    assert_includes result.error_message, "Invalid SSN format"
  end

  test "business rules engine integration" do
    business_rules = @validation_engine.instance_variable_get(:@business_rules)
    
    # Test patient record validation
    result = business_rules.validate_record(2, @valid_patient_data)
    assert result.success?
    
    # Test with business rule violation
    invalid_data = @valid_patient_data.merge({
      "0.03" => "1990-01-01", # Adult
      "consent_flag" => "N"    # No consent
    })
    
    result = business_rules.validate_record(2, invalid_data)
    refute result.success?
    assert_includes result.errors, "Adult patient must have consent on file"
  end

  test "provider record validation" do
    provider_data = {
      "0.01" => "PHYSICIAN,ATTENDING",
      "provider_type" => "MD",
      "license_number" => "12345",
      "dea_number" => "AB1234567"
    }
    
    result = @validation_engine.validate_new_record(200, provider_data)
    assert result.success?
  end

  test "complex validation scenarios" do
    # Pediatric patient scenario
    pediatric_data = @valid_patient_data.merge({
      "0.03" => (Date.current - 10.years).to_s, # 10 years old
      "guardian_name" => "SMITH,PARENT",
      "guardian_consent" => "Y"
    })
    
    result = @validation_engine.validate_new_record(2, pediatric_data)
    assert result.success?
    
    # Same data but missing guardian info
    pediatric_no_guardian = pediatric_data.merge({
      "guardian_name" => "",
      "guardian_consent" => ""
    })
    
    result = @validation_engine.validate_new_record(2, pediatric_no_guardian)
    refute result.success?
    # Should require guardian information for minors
  end

  test "validation result accumulation" do
    # Data with multiple validation errors
    multi_error_data = {
      "0.01" => "", # Missing name
      "0.02" => "INVALID", # Invalid gender
      "0.03" => "future-date", # Invalid date
      "0.09" => "abc" # Invalid SSN
    }
    
    result = @validation_engine.validate_new_record(2, multi_error_data)
    
    refute result.success?
    assert result.errors.length >= 4 # Should capture all validation errors
    
    # Check that we get errors from different validation layers
    errors_text = result.errors.join(" ")
    assert_includes errors_text, "required" # Field validation
    assert_includes errors_text, "Invalid" # Format validation
  end

  private

  def setup_mock_data_dictionary
    dd = Minitest::Mock.new
    
    # Mock field definitions for patient file
    name_field = FieldDefinition.new(
      name: "NAME", type: "FREE TEXT", length: 50, required: true
    )
    
    gender_field = FieldDefinition.new(
      name: "SEX", type: "SET", length: 1, required: true,
      validation_pattern: "M:MALE;F:FEMALE;U:UNKNOWN"
    )
    
    dob_field = FieldDefinition.new(
      name: "DOB", type: "DATE", length: 8, required: true
    )
    
    ssn_field = FieldDefinition.new(
      name: "SSN", type: "SSN", length: 9, required: true,
      validation_pattern: "\\d{9}"
    )
    
    phone_field = FieldDefinition.new(
      name: "PHONE", type: "FREE TEXT", length: 20, required: false
    )
    
    # Set up expectations for field definitions
    dd.expect(:get_field_definition, name_field, [2, "0.01"])
    dd.expect(:get_field_definition, gender_field, [2, "0.02"]) 
    dd.expect(:get_field_definition, dob_field, [2, "0.03"])
    dd.expect(:get_field_definition, ssn_field, [2, "0.09"])
    dd.expect(:get_field_definition, phone_field, [2, "0.131"])
    
    # Allow multiple calls to the same field definitions
    10.times do
      dd.expect(:get_field_definition, name_field, [2, "0.01"])
      dd.expect(:get_field_definition, gender_field, [2, "0.02"])
      dd.expect(:get_field_definition, dob_field, [2, "0.03"])
      dd.expect(:get_field_definition, ssn_field, [2, "0.09"])
      dd.expect(:get_field_definition, phone_field, [2, "0.131"])
    end
    
    dd
  end
end