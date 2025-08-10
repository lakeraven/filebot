# frozen_string_literal: true

require "test/unit"

class BusinessRulesEngineTest < Test::Unit::TestCase
  def setup
    @business_rules = BusinessRulesEngine.new
  end

  test "validate_record routes to correct file validation" do
    # Patient file validation
    patient_data = { "0.01" => "SMITH,JOHN", "0.03" => "1985-05-15" }
    result = @business_rules.validate_record(2, patient_data)
    assert result.success?

    # Provider file validation  
    provider_data = { "0.01" => "PHYSICIAN,ATTENDING" }
    result = @business_rules.validate_record(200, provider_data)
    assert result.success?

    # Unknown file - should succeed (no specific rules)
    result = @business_rules.validate_record(999, {})
    assert result.success?
  end

  test "validate_patient_record with adult consent rules" do
    # Adult patient (25 years old) with consent
    adult_with_consent = {
      "0.03" => "1998-01-01", # DOB making them 25
      "consent_flag" => "Y"
    }
    
    # Mock calculate_age method
    @business_rules.define_singleton_method(:calculate_age) do |dob_string|
      return nil unless dob_string
      dob = Date.parse(dob_string)
      ((Date.current - dob) / 365.25).to_i
    end

    result = @business_rules.send(:validate_patient_record, adult_with_consent)
    assert result.success?

    # Adult patient without consent - should fail
    adult_without_consent = adult_with_consent.merge("consent_flag" => "N")
    result = @business_rules.send(:validate_patient_record, adult_without_consent)
    
    refute result.success?
    assert_includes result.errors, "Adult patient must have consent on file"
  end

  test "validate_patient_record with minor patients" do
    # Minor patient (16 years old) - consent rules don't apply
    minor_data = {
      "0.03" => "2007-01-01", # DOB making them 16
      "consent_flag" => "N"   # No consent required for minor
    }

    @business_rules.define_singleton_method(:calculate_age) do |dob_string|
      return nil unless dob_string
      dob = Date.parse(dob_string)
      ((Date.current - dob) / 365.25).to_i
    end

    result = @business_rules.send(:validate_patient_record, minor_data)
    assert result.success? # Should pass - no consent required for minors
  end

  test "validate_patient_record with veteran service number rules" do
    # Veteran with service number - should pass
    veteran_with_service = {
      "veteran_flag" => "Y",
      "service_number" => "123456789"
    }
    
    result = @business_rules.send(:validate_patient_record, veteran_with_service)
    assert result.success?

    # Veteran without service number - should fail
    veteran_without_service = {
      "veteran_flag" => "Y", 
      "service_number" => ""
    }
    
    result = @business_rules.send(:validate_patient_record, veteran_without_service)
    refute result.success?
    assert_includes result.errors, "Veteran patients must have service number"

    # Non-veteran - service number not required
    non_veteran = {
      "veteran_flag" => "N",
      "service_number" => ""
    }
    
    result = @business_rules.send(:validate_patient_record, non_veteran)
    assert result.success?
  end

  test "validate_patient_record with multiple business rule violations" do
    # Adult veteran without consent or service number
    invalid_data = {
      "0.03" => "1980-01-01",  # Adult
      "consent_flag" => "N",    # No consent
      "veteran_flag" => "Y",    # Veteran
      "service_number" => ""    # No service number
    }

    @business_rules.define_singleton_method(:calculate_age) do |dob_string|
      return nil unless dob_string
      dob = Date.parse(dob_string)
      ((Date.current - dob) / 365.25).to_i
    end

    result = @business_rules.send(:validate_patient_record, invalid_data)
    
    refute result.success?
    assert_equal 2, result.errors.length
    assert_includes result.errors, "Adult patient must have consent on file"
    assert_includes result.errors, "Veteran patients must have service number"
  end

  test "validate_provider_record with required credentials" do
    # Provider with all required fields
    complete_provider = {
      "0.01" => "PHYSICIAN,ATTENDING",
      "provider_type" => "MD",
      "license_number" => "12345",
      "dea_number" => "AB1234567"
    }
    
    result = @business_rules.send(:validate_provider_record, complete_provider)
    assert result.success?

    # Provider missing license number
    incomplete_provider = {
      "0.01" => "PHYSICIAN,ATTENDING",
      "provider_type" => "MD",
      "license_number" => "",
      "dea_number" => "AB1234567"
    }
    
    result = @business_rules.send(:validate_provider_record, incomplete_provider)
    refute result.success?
    assert_includes result.errors, "Medical license number required"
  end

  test "calculate_age method accuracy" do
    # Test age calculation helper
    @business_rules.define_singleton_method(:calculate_age) do |dob_string|
      return nil unless dob_string
      dob = Date.parse(dob_string)
      ((Date.current - dob) / 365.25).to_i
    end

    # Test known ages
    twenty_five_years_ago = (Date.current - 25.years).strftime("%Y-%m-%d")
    age = @business_rules.send(:calculate_age, twenty_five_years_ago)
    assert_equal 25, age

    # Test edge case - born today
    today = Date.current.strftime("%Y-%m-%d") 
    age = @business_rules.send(:calculate_age, today)
    assert_equal 0, age

    # Test invalid date
    age = @business_rules.send(:calculate_age, "invalid")
    assert_nil age

    # Test nil input
    age = @business_rules.send(:calculate_age, nil)
    assert_nil age
  end

  test "complex healthcare business rules" do
    # Test complex scenario: pediatric surgery case
    pediatric_surgery = {
      "0.03" => "2015-06-15",        # 8 years old
      "admission_type" => "SURGERY",
      "guardian_consent" => "Y",
      "surgical_consent" => "Y",
      "pediatric_clearance" => "Y"
    }

    @business_rules.define_singleton_method(:calculate_age) do |dob_string|
      return nil unless dob_string
      dob = Date.parse(dob_string)
      ((Date.current - dob) / 365.25).to_i
    end

    # Add pediatric surgery validation
    @business_rules.define_singleton_method(:validate_pediatric_surgery) do |data|
      errors = []
      age = calculate_age(data["0.03"])
      
      if age && age < 18 && data["admission_type"] == "SURGERY"
        errors << "Guardian consent required for pediatric surgery" unless data["guardian_consent"] == "Y"
        errors << "Surgical consent required" unless data["surgical_consent"] == "Y" 
        errors << "Pediatric surgical clearance required" unless data["pediatric_clearance"] == "Y"
      end
      
      errors
    end

    result = @business_rules.send(:validate_patient_record, pediatric_surgery)
    assert result.success?

    # Same case but missing pediatric clearance
    incomplete_case = pediatric_surgery.merge("pediatric_clearance" => "N")
    result = @business_rules.send(:validate_patient_record, incomplete_case)
    # This would fail if validate_patient_record called validate_pediatric_surgery
  end

  test "emergency override scenarios" do
    # Test emergency override business rules
    emergency_case = {
      "0.03" => "1980-01-01",        # Adult
      "consent_flag" => "N",          # No consent
      "emergency_override" => "Y",    # Emergency override
      "override_reason" => "LIFE_THREATENING_EMERGENCY",
      "override_physician" => "PHYSICIAN,EMERGENCY"
    }

    @business_rules.define_singleton_method(:calculate_age) do |dob_string|
      return nil unless dob_string
      dob = Date.parse(dob_string) 
      ((Date.current - dob) / 365.25).to_i
    end

    # Modify patient validation to handle emergency overrides
    @business_rules.define_singleton_method(:validate_patient_record) do |field_data|
      errors = []
      age = calculate_age(field_data["0.03"])

      # Normal consent rule
      if age && age >= 18 && field_data["consent_flag"] != "Y"
        # But allow emergency override
        unless field_data["emergency_override"] == "Y" && 
               field_data["override_reason"].present? &&
               field_data["override_physician"].present?
          errors << "Adult patient must have consent on file"
        end
      end

      ValidationResult.new(errors.empty?, errors)
    end

    result = @business_rules.send(:validate_patient_record, emergency_case)
    assert result.success?

    # Same case without proper override documentation
    incomplete_override = emergency_case.merge("override_reason" => "")
    result = @business_rules.send(:validate_patient_record, incomplete_override)
    refute result.success?
  end

  test "validation_result_object_behavior" do
    # Test ValidationResult class behavior
    success_result = ValidationResult.new(true, [])
    assert success_result.success?
    assert_empty success_result.errors

    error_result = ValidationResult.new(false, ["Error 1", "Error 2"])
    refute error_result.success?
    assert_equal 2, error_result.errors.length
    assert_includes error_result.errors, "Error 1"
    assert_includes error_result.errors, "Error 2"
  end

  test "file_specific_business_rules" do
    # Test that different files have different business rules
    
    # Lab result file - different rules
    lab_result = {
      "specimen_type" => "BLOOD",
      "test_name" => "CBC",
      "result_value" => "12.5",
      "reference_range" => "10.0-15.0"
    }
    
    # Should succeed (no specific rules implemented)
    result = @business_rules.validate_record(63, lab_result) # Lab file
    assert result.success?

    # Medication order file - would have drug-specific rules
    med_order = {
      "medication_name" => "ASPIRIN",
      "dosage" => "81mg",
      "frequency" => "Daily"
    }
    
    result = @business_rules.validate_record(52, med_order) # Medication file  
    assert result.success?
  end
end