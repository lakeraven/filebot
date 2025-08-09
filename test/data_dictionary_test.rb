# frozen_string_literal: true

require "test_helper"

class DataDictionaryTest < ActiveSupport::TestCase
  def setup
    @iris_connection = mock_iris_connection
    @data_dictionary = DataDictionary.new(@iris_connection)
  end

  test "get_field_definition retrieves field definition" do
    # Mock IRIS global data for patient name field
    mock_dd_data = "NAME^FREE TEXT^50^R^^PATIENT NAME^Enter the patient's full name"
    
    iris_global_mock = Minitest::Mock.new
    iris_global_mock.expect(:get, mock_dd_data, ["DD", 2, 0.01, 0])
    
    @iris_connection.expect(:createIRIS, iris_global_mock)
    
    field_def = @data_dictionary.get_field_definition(2, 0.01)
    
    assert_not_nil field_def
    assert_equal "NAME", field_def.name
    assert_equal "FREE TEXT", field_def.type
    assert_equal 50, field_def.length
    assert field_def.required
    assert_equal "PATIENT NAME", field_def.help_text
    
    iris_global_mock.verify
    @iris_connection.verify
  end

  test "field definition caching" do
    mock_dd_data = "SSN^NUMERIC^9^R^^SOCIAL SECURITY NUMBER^Enter 9-digit SSN"
    
    iris_global_mock = Minitest::Mock.new
    iris_global_mock.expect(:get, mock_dd_data, ["DD", 2, 0.09, 0])
    
    @iris_connection.expect(:createIRIS, iris_global_mock)
    
    # First call should hit IRIS
    field_def1 = @data_dictionary.get_field_definition(2, 0.09)
    
    # Second call should use cache (no additional IRIS calls expected)
    field_def2 = @data_dictionary.get_field_definition(2, 0.09)
    
    assert_equal field_def1.name, field_def2.name
    assert_equal field_def1.type, field_def2.type
    
    iris_global_mock.verify
    @iris_connection.verify
  end

  test "parse_dd_entry handles all field types" do
    test_cases = [
      {
        input: "NAME^FREE TEXT^50^R^UPPER^NAME TRANSFORM^Enter patient name",
        expected: {
          name: "NAME",
          type: "FREE TEXT", 
          length: 50,
          required: true,
          input_transform: "UPPER",
          output_transform: "NAME TRANSFORM",
          help_text: "Enter patient name"
        }
      },
      {
        input: "DOB^DATE^8^^DATE^DATE TRANSFORM^Enter date of birth",
        expected: {
          name: "DOB",
          type: "DATE",
          length: 8,
          required: false,
          input_transform: "DATE",
          output_transform: "DATE TRANSFORM", 
          help_text: "Enter date of birth"
        }
      }
    ]
    
    test_cases.each do |test_case|
      field_def = @data_dictionary.send(:parse_dd_entry, test_case[:input])
      
      test_case[:expected].each do |key, value|
        assert_equal value, field_def.send(key), "Mismatch for #{key} in #{test_case[:input]}"
      end
    end
  end

  test "handles missing field definition" do
    iris_global_mock = Minitest::Mock.new
    iris_global_mock.expect(:get, "", ["DD", 999, 999, 0])
    
    @iris_connection.expect(:createIRIS, iris_global_mock)
    
    field_def = @data_dictionary.get_field_definition(999, 999)
    
    assert_nil field_def
    
    iris_global_mock.verify
    @iris_connection.verify
  end

  test "parse_cross_references extracts cross-reference info" do
    xref_data = "B^REGULAR^Name index|AC^SOUNDEX^Phonetic name search"
    
    cross_refs = @data_dictionary.send(:parse_cross_references, xref_data)
    
    assert_equal 2, cross_refs.length
    
    b_ref = cross_refs.find { |ref| ref.name == "B" }
    assert_not_nil b_ref
    assert_equal "REGULAR", b_ref.type
    assert_equal "Name index", b_ref.description
    
    ac_ref = cross_refs.find { |ref| ref.name == "AC" }
    assert_not_nil ac_ref
    assert_equal "SOUNDEX", ac_ref.type
    assert_equal "Phonetic name search", ac_ref.description
  end

  test "field definition validation attributes" do
    # Test numeric field
    numeric_data = "AGE^NUMERIC^3^^0:150^^Enter patient age in years"
    field_def = @data_dictionary.send(:parse_dd_entry, numeric_data)
    
    assert_equal "NUMERIC", field_def.type
    assert_equal 3, field_def.length
    assert_equal "0:150", field_def.validation_pattern
    
    # Test set of codes field
    gender_data = "SEX^SET^1^R^M:MALE;F:FEMALE;U:UNKNOWN^^Enter patient gender"
    field_def = @data_dictionary.send(:parse_dd_entry, gender_data)
    
    assert_equal "SET", field_def.type
    assert_equal 1, field_def.length
    assert field_def.required
    assert_equal "M:MALE;F:FEMALE;U:UNKNOWN", field_def.validation_pattern
  end

  private

  def mock_iris_connection
    Minitest::Mock.new
  end
end