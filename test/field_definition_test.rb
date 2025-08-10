# frozen_string_literal: true

require "test/unit"

class FieldDefinitionTest < Test::Unit::TestCase
  def setup
    @name_field = FieldDefinition.new(
      name: "PATIENT NAME",
      type: "FREE TEXT",
      length: 50,
      required: true,
      validation_pattern: nil,
      help_text: "Enter patient's full name"
    )

    @ssn_field = FieldDefinition.new(
      name: "SSN",
      type: "SSN",
      length: 9,
      required: true,
      validation_pattern: "\\d{9}",
      help_text: "Enter 9-digit social security number"
    )

    @dob_field = FieldDefinition.new(
      name: "DATE OF BIRTH", 
      type: "DATE",
      length: 8,
      required: true,
      validation_pattern: nil,
      help_text: "Enter patient's date of birth"
    )

    @gender_field = FieldDefinition.new(
      name: "SEX",
      type: "SET",
      length: 1,
      required: true,
      validation_pattern: "M:MALE;F:FEMALE;U:UNKNOWN",
      help_text: "Enter patient gender"
    )
  end

  test "field definition initialization" do
    assert_equal "PATIENT NAME", @name_field.name
    assert_equal "FREE TEXT", @name_field.type
    assert_equal 50, @name_field.length
    assert @name_field.required
    assert_nil @name_field.validation_pattern
    assert_equal "Enter patient's full name", @name_field.help_text
  end

  test "validate_value with valid data" do
    # Valid name
    result = @name_field.validate_value("SMITH,JOHN")
    assert result.success?
    assert_empty result.errors

    # Valid SSN
    result = @ssn_field.validate_value("123456789")
    assert result.success?

    # Valid date
    result = @dob_field.validate_value("1985-05-15")
    assert result.success?

    # Valid gender
    result = @gender_field.validate_value("M")
    assert result.success?
  end

  test "validate_value with required field missing" do
    result = @name_field.validate_value("")
    refute result.success?
    assert_includes result.errors, "Field PATIENT NAME is required"

    result = @name_field.validate_value(nil)
    refute result.success?
    assert_includes result.errors, "Field PATIENT NAME is required"
  end

  test "validate_value with length exceeded" do
    long_name = "A" * 51  # Exceeds 50 character limit
    result = @name_field.validate_value(long_name)
    
    refute result.success?
    assert_includes result.errors, "Value too long for PATIENT NAME"
  end

  test "validate_value with pattern mismatch" do
    # Invalid SSN format
    result = @ssn_field.validate_value("12-34-5678")
    refute result.success?
    assert_includes result.errors, "Invalid format for SSN"

    result = @ssn_field.validate_value("12345678") # Too short
    refute result.success?
    assert_includes result.errors, "Invalid format for SSN"
  end

  test "validate_date_field with valid dates" do
    valid_dates = ["1985-05-15", "2000-12-31", "1950-01-01"]
    
    valid_dates.each do |date_string|
      result = @dob_field.validate_value(date_string)
      assert result.success?, "Date #{date_string} should be valid"
    end
  end

  test "validate_date_field with invalid dates" do
    # Future date
    future_date = (Date.current + 1.year).to_s
    result = @dob_field.validate_value(future_date)
    refute result.success?
    assert_includes result.errors, "Date cannot be in future"

    # Invalid format
    result = @dob_field.validate_value("invalid-date")
    refute result.success?
    assert_includes result.errors, "Invalid date format"

    # Too old (over 150 years)
    old_date = (Date.current - 151.years).to_s
    result = @dob_field.validate_value(old_date)
    refute result.success?
    assert_includes result.errors, "Patient cannot be over 150 years old"
  end

  test "validate_ssn_field with healthcare rules" do
    # Valid SSN
    result = @ssn_field.validate_value("123456789")
    assert result.success?

    # Invalid SSN ranges
    invalid_ssns = ["000000000", "123456789", "999999999"]
    
    # Note: This test assumes invalid_ssn_ranges method exists
    # In actual implementation, this would check against known invalid ranges
    result = @ssn_field.validate_value("000000000")
    refute result.success?
    assert_includes result.errors, "Invalid SSN number"
  end

  test "validate_numeric_field" do
    numeric_field = FieldDefinition.new(
      name: "AGE",
      type: "NUMERIC", 
      length: 3,
      required: true,
      validation_pattern: "0:150",
      help_text: "Enter patient age"
    )

    # Valid ages
    ["25", "0", "150"].each do |age|
      result = numeric_field.validate_value(age)
      assert result.success?, "Age #{age} should be valid"
    end

    # Invalid ages
    result = numeric_field.validate_value("151")
    refute result.success?
    assert_includes result.errors, "Value out of range for AGE"

    result = numeric_field.validate_value("-1")
    refute result.success?
    assert_includes result.errors, "Value out of range for AGE"

    result = numeric_field.validate_value("abc")
    refute result.success?
    assert_includes result.errors, "Invalid numeric value for AGE"
  end

  test "validate_set_field" do
    # Valid values from set
    ["M", "F", "U"].each do |gender|
      result = @gender_field.validate_value(gender)
      assert result.success?, "Gender #{gender} should be valid"
    end

    # Invalid value not in set
    result = @gender_field.validate_value("X")
    refute result.success?
    assert_includes result.errors, "Invalid value for SEX. Must be one of: M, F, U"
  end

  test "multiple validation errors" do
    # Field that's too long AND has invalid pattern
    long_invalid_ssn = "123-45-67890" # Too long and has dashes
    
    ssn_field = FieldDefinition.new(
      name: "SSN",
      type: "SSN",
      length: 9,
      required: true,
      validation_pattern: "\\d{9}",
      help_text: "Enter SSN"
    )

    result = ssn_field.validate_value(long_invalid_ssn)
    refute result.success?
    assert result.errors.length >= 1 # Should have at least one error
  end

  test "optional field validation" do
    optional_field = FieldDefinition.new(
      name: "MIDDLE NAME",
      type: "FREE TEXT",
      length: 20,
      required: false,
      help_text: "Enter middle name if known"
    )

    # Empty value should be valid for optional field
    result = optional_field.validate_value("")
    assert result.success?

    result = optional_field.validate_value(nil)
    assert result.success?

    # But if provided, should still validate length
    result = optional_field.validate_value("A" * 21)
    refute result.success?
    assert_includes result.errors, "Value too long for MIDDLE NAME"
  end
end