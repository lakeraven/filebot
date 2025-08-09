# frozen_string_literal: true

require "test_helper"

class HealthcareValidatorTest < ActiveSupport::TestCase
  def setup
    @healthcare_validator = HealthcareValidator.new
  end

  test "validate_field routes to correct validation method" do
    # Patient name validation
    result = @healthcare_validator.validate_field(2, "0.01", "SMITH,JOHN")
    assert result.success?
    
    # Patient SSN validation  
    result = @healthcare_validator.validate_field(2, "0.09", "123456789")
    assert result.success?
    
    # Patient DOB validation
    result = @healthcare_validator.validate_field(2, "0.03", "1985-05-15")
    assert result.success?
    
    # Provider name validation
    result = @healthcare_validator.validate_field(200, "0.01", "PHYSICIAN,ATTENDING")
    assert result.success?
  end

  test "validate_patient_name with valid names" do
    valid_names = [
      "SMITH,JOHN",
      "O'CONNOR,MARY",
      "VAN DER BERG,PETER",
      "MARTINEZ-LOPEZ,CARLOS"
    ]
    
    valid_names.each do |name|
      result = @healthcare_validator.send(:validate_patient_name, name)
      assert result.success?, "Name '#{name}' should be valid"
    end
  end

  test "validate_patient_name with invalid names" do
    invalid_cases = [
      { name: "", expected_error: "Name required" },
      { name: "A" * 51, expected_error: "Name too long" },
      { name: "SMITH123,JOHN", expected_error: "Invalid characters in name" },
      { name: "TEST,PATIENT", expected_error: "Test patient name not allowed in production" },
      { name: "DOE,JOHN", expected_error: "Test patient name not allowed in production" },
      { name: "MOUSE,MICKEY", expected_error: "Test patient name not allowed in production" }
    ]
    
    invalid_cases.each do |test_case|
      result = @healthcare_validator.send(:validate_patient_name, test_case[:name])
      refute result.success?, "Name '#{test_case[:name]}' should be invalid"
      assert_includes result.error_message, test_case[:expected_error]
    end
  end

  test "validate_patient_ssn with valid SSNs" do
    valid_ssns = ["123456789", "987654321", "555443333"]
    
    valid_ssns.each do |ssn|
      # Mock find_patient_by_ssn to return nil (no duplicate)
      @healthcare_validator.define_singleton_method(:find_patient_by_ssn) { |ssn| nil }
      
      result = @healthcare_validator.send(:validate_patient_ssn, ssn)
      assert result.success?, "SSN '#{ssn}' should be valid"
    end
  end

  test "validate_patient_ssn with invalid SSNs" do
    invalid_cases = [
      { ssn: "", expected_error: "SSN required" },
      { ssn: "12345678", expected_error: "Invalid SSN format" },
      { ssn: "1234567890", expected_error: "Invalid SSN format" },
      { ssn: "123-45-6789", expected_error: "Invalid SSN format" },
      { ssn: "000000000", expected_error: "Invalid SSN number" },
      { ssn: "123456789", expected_error: "Invalid SSN number" },
      { ssn: "999999999", expected_error: "Invalid SSN number" }
    ]
    
    invalid_cases.each do |test_case|
      result = @healthcare_validator.send(:validate_patient_ssn, test_case[:ssn])
      refute result.success?, "SSN '#{test_case[:ssn]}' should be invalid"
      assert_includes result.error_message, test_case[:expected_error]
    end
  end

  test "validate_patient_ssn with duplicate SSN" do
    # Mock existing patient with same SSN
    @healthcare_validator.define_singleton_method(:find_patient_by_ssn) { |ssn| 456 }
    
    result = @healthcare_validator.send(:validate_patient_ssn, "123456789")
    refute result.success?
    assert_includes result.error_message, "SSN already exists for patient 456"
  end

  test "validate_patient_dob with valid dates" do
    valid_dates = [
      "1985-05-15",
      "2000-12-31", 
      "1950-01-01",
      (Date.current - 30.years).to_s
    ]
    
    valid_dates.each do |date_string|
      result = @healthcare_validator.send(:validate_patient_dob, date_string)
      assert result.success?, "DOB '#{date_string}' should be valid"
    end
  end

  test "validate_patient_dob with invalid dates" do
    invalid_cases = [
      { 
        dob: (Date.current + 1.day).to_s, 
        expected_error: "DOB cannot be in future" 
      },
      { 
        dob: (Date.current - 151.years).to_s, 
        expected_error: "Patient cannot be over 150 years old" 
      },
      { 
        dob: "invalid-date", 
        expected_error: "Invalid date format" 
      },
      { 
        dob: "2023-13-01", 
        expected_error: "Invalid date format" 
      }
    ]
    
    invalid_cases.each do |test_case|
      result = @healthcare_validator.send(:validate_patient_dob, test_case[:dob])
      refute result.success?, "DOB '#{test_case[:dob]}' should be invalid"
      assert_includes result.error_message, test_case[:expected_error]
    end
  end

  test "validate_provider_name with valid names" do
    valid_provider_names = [
      "PHYSICIAN,ATTENDING",
      "NURSE,REGISTERED", 
      "SPECIALIST,CARDIAC",
      "THERAPIST,PHYSICAL"
    ]
    
    valid_provider_names.each do |name|
      result = @healthcare_validator.send(:validate_provider_name, name)
      assert result.success?, "Provider name '#{name}' should be valid"
    end
  end

  test "healthcare field validation for unknown fields" do
    # Should return success for fields not specifically handled
    result = @healthcare_validator.validate_field(2, "0.11", "123 MAIN ST")
    assert result.success?
    
    result = @healthcare_validator.validate_field(999, "0.01", "UNKNOWN FILE")
    assert result.success?
  end

  test "integration with IRIS for duplicate checking" do
    # This would test actual IRIS integration if available
    # For now, test the interface
    
    # Mock the find_patient_by_ssn method
    @healthcare_validator.define_singleton_method(:find_patient_by_ssn) do |ssn|
      # Simulate IRIS lookup
      case ssn
      when "111111111"
        123 # Return existing patient DFN
      else
        nil # No match found
      end
    end
    
    # Test unique SSN
    result = @healthcare_validator.send(:validate_patient_ssn, "123456789")
    assert result.success?
    
    # Test duplicate SSN
    result = @healthcare_validator.send(:validate_patient_ssn, "111111111")
    refute result.success?
    assert_includes result.error_message, "SSN already exists for patient 123"
  end

  test "comprehensive patient validation" do
    # Test all patient fields together
    test_cases = [
      {
        description: "Valid complete patient",
        data: [
          [2, "0.01", "SMITH,JOHN"],
          [2, "0.02", "M"],
          [2, "0.03", "1985-05-15"],
          [2, "0.09", "123456789"]
        ],
        should_pass: true
      },
      {
        description: "Invalid patient with multiple errors",
        data: [
          [2, "0.01", "TEST,PATIENT"],  # Prohibited name
          [2, "0.02", "M"],
          [2, "0.03", "2050-01-01"],    # Future date
          [2, "0.09", "000000000"]      # Invalid SSN
        ],
        should_pass: false
      }
    ]
    
    test_cases.each do |test_case|
      # Mock find_patient_by_ssn to return nil for these tests
      @healthcare_validator.define_singleton_method(:find_patient_by_ssn) { |ssn| nil }
      
      results = test_case[:data].map do |file_num, field_num, value|
        @healthcare_validator.validate_field(file_num, field_num, value)
      end
      
      if test_case[:should_pass]
        assert results.all?(&:success?), "#{test_case[:description]} should pass validation"
      else
        assert results.any? { |r| !r.success? }, "#{test_case[:description]} should fail validation"
      end
    end
  end
end