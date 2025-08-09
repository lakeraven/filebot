# frozen_string_literal: true

# FileBot Test Helper - JRuby unit testing support for FileBot system
require_relative "../test_helper"
require "java"

# Import IRIS Native API for JRuby testing
java_import "com.intersystems.jdbc.IRISConnection"
java_import "com.intersystems.jdbc.IRISDataSource"

module FileBotTestHelper
  # Mock classes for FileBot system components
  
  class MockFileBot
    attr_accessor :data_store, :validation_errors, :should_fail
    
    def initialize
      @data_store = {}
      @validation_errors = []
      @should_fail = false
    end
    
    def gets(file_number, iens, fields, flags = "EI")
      return error_result("Mock failure") if @should_fail
      
      key = "#{file_number}_#{iens}"
      data = @data_store[key] || {}
      
      OpenStruct.new(
        success?: true,
        data: data,
        errors: []
      )
    end
    
    def file_new(file_number, field_data)
      return { success: false, errors: @validation_errors } if @should_fail
      
      iens = rand(1000..9999)
      key = "#{file_number}_#{iens},"
      @data_store[key] = field_data
      
      {
        success: true,
        iens: iens,
        record: { message: "Record created successfully" }
      }
    end
    
    def update(file_number, iens, field_data)
      return error_result("Mock update failure") if @should_fail
      
      key = "#{file_number}_#{iens}"
      @data_store[key] = (@data_store[key] || {}).merge(field_data)
      
      OpenStruct.new(
        success?: true,
        errors: []
      )
    end
    
    private
    
    def error_result(message)
      OpenStruct.new(
        success?: false,
        errors: [message]
      )
    end
  end
  
  class MockDataDictionary
    attr_accessor :field_definitions
    
    def initialize
      @field_definitions = setup_default_field_definitions
    end
    
    def get_field_definition(file_number, field_number)
      key = "#{file_number}_#{field_number}"
      @field_definitions[key] || default_field_definition
    end
    
    def parse_data_dictionary(file_number)
      {
        file_number => {
          global_name: get_global_name_for_file(file_number),
          fields: get_fields_for_file(file_number)
        }
      }
    end
    
    private
    
    def setup_default_field_definitions
      {
        "2_0.01" => mock_name_field,
        "2_0.02" => mock_sex_field,
        "2_0.03" => mock_dob_field,
        "2_0.09" => mock_ssn_field,
        "2_0.11" => mock_street_field,
        "2_0.131" => mock_phone_field,
        "200_0.01" => mock_provider_name_field
      }
    end
    
    def mock_name_field
      OpenStruct.new(
        field_number: "0.01",
        field_name: "NAME",
        data_type: "FREE TEXT",
        length: 30,
        required: true,
        cross_references: [OpenStruct.new(type: "B", name: "B")],
        help_text: "Patient name in LAST,FIRST format",
        input_transform: "K:$L(X)>30!($L(X)<3)!'(X?1A.E) X"
      )
    end
    
    def mock_sex_field
      OpenStruct.new(
        field_number: "0.02",
        field_name: "SEX",
        data_type: "SET",
        set_of_codes: { "M" => "MALE", "F" => "FEMALE" },
        required: false,
        cross_references: [OpenStruct.new(type: "BITMAP", name: "SEX")]
      )
    end
    
    def mock_dob_field
      OpenStruct.new(
        field_number: "0.03",
        field_name: "DATE OF BIRTH",
        data_type: "DATE",
        required: false,
        cross_references: [],
        help_text: "Patient date of birth"
      )
    end
    
    def mock_ssn_field
      OpenStruct.new(
        field_number: "0.09",
        field_name: "SOCIAL SECURITY NUMBER",
        data_type: "FREE TEXT",
        length: 9,
        required: false,
        cross_references: [OpenStruct.new(type: "UNIQUE", name: "SSN")]
      )
    end
    
    def mock_street_field
      OpenStruct.new(
        field_number: "0.11",
        field_name: "STREET ADDRESS [LINE 1]",
        data_type: "FREE TEXT",
        length: 35,
        required: false
      )
    end
    
    def mock_phone_field
      OpenStruct.new(
        field_number: "0.131",
        field_name: "PHONE NUMBER [RESIDENCE]",
        data_type: "FREE TEXT",
        length: 20,
        required: false
      )
    end
    
    def mock_provider_name_field
      OpenStruct.new(
        field_number: "0.01",
        field_name: "NAME",
        data_type: "FREE TEXT",
        length: 50,
        required: true
      )
    end
    
    def default_field_definition
      OpenStruct.new(
        field_number: "0.01",
        field_name: "UNKNOWN FIELD",
        data_type: "FREE TEXT",
        required: false,
        cross_references: []
      )
    end
    
    def get_global_name_for_file(file_number)
      case file_number
      when 2
        "DPT"
      when 200
        "VA"
      when 52
        "PS"
      when 63
        "LAB"
      else
        "UNKNOWN"
      end
    end
    
    def get_fields_for_file(file_number)
      case file_number
      when 2
        %w[0.01 0.02 0.03 0.09 0.11 0.131]
      when 200
        %w[0.01]
      else
        []
      end
    end
  end
  
  class MockHealthcareValidator
    attr_accessor :should_fail_validation
    
    def initialize
      @should_fail_validation = false
    end
    
    def validate_field(file_number, field_number, value)
      return ValidationResult.new(false, ["Mock validation failure"]) if @should_fail_validation
      
      # Simulate healthcare-specific validation
      case field_number
      when "0.01" # Name
        validate_patient_name(value)
      when "0.09" # SSN
        validate_patient_ssn(value)
      when "0.03" # DOB
        validate_patient_dob(value)
      else
        ValidationResult.new(true, [])
      end
    end
    
    private
    
    def validate_patient_name(name)
      errors = []
      errors << "Name required" if name.blank?
      errors << "Name too long" if name&.length.to_i > 50
      errors << "Test patient name not allowed in production" if name&.match?(/TEST|DOE|MOUSE/)
      
      ValidationResult.new(errors.empty?, errors)
    end
    
    def validate_patient_ssn(ssn)
      errors = []
      errors << "SSN required" if ssn.blank?
      errors << "Invalid SSN format" unless ssn&.match?(/^\d{9}$/)
      errors << "Invalid SSN number" if ssn&.match?(/^(000|666|9\d{2})/)
      
      ValidationResult.new(errors.empty?, errors)
    end
    
    def validate_patient_dob(dob_string)
      errors = []
      
      begin
        dob = Date.parse(dob_string) if dob_string.present?
        errors << "DOB cannot be in future" if dob && dob > Date.current
        errors << "Patient cannot be over 150 years old" if dob && dob < (Date.current - 150.years)
      rescue Date::Error
        errors << "Invalid date format"
      end
      
      ValidationResult.new(errors.empty?, errors)
    end
  end
  
  class MockCrossReferenceManager
    attr_accessor :cross_references_built
    
    def initialize(iris_connection = nil)
      @iris_connection = iris_connection
      @cross_references_built = []
    end
    
    def build_references(file_number, iens, field_data)
      @cross_references_built << {
        file: file_number,
        iens: iens,
        fields: field_data.keys
      }
    end
    
    def update_references(file_number, iens, field_data)
      @cross_references_built << {
        action: :update,
        file: file_number,
        iens: iens,
        fields: field_data.keys
      }
    end
  end
  
  class MockBusinessRulesEngine
    attr_accessor :should_fail_business_rules
    
    def initialize
      @should_fail_business_rules = false
    end
    
    def validate_record(file_number, field_data)
      return ValidationResult.new(false, ["Mock business rule failure"]) if @should_fail_business_rules
      
      case file_number
      when 2 # Patient file
        validate_patient_business_rules(field_data)
      when 200 # Provider file
        validate_provider_business_rules(field_data)
      else
        ValidationResult.new(true, [])
      end
    end
    
    private
    
    def validate_patient_business_rules(field_data)
      errors = []
      
      # Adult consent rule
      if field_data["0.03"] # DOB field
        age = calculate_age(field_data["0.03"])
        if age && age >= 18 && field_data["consent_flag"] != "Y"
          errors << "Adult patient must have consent on file"
        end
      end
      
      # Veteran service number rule
      if field_data["veteran_flag"] == "Y" && field_data["service_number"].blank?
        errors << "Veteran patients must have service number"
      end
      
      ValidationResult.new(errors.empty?, errors)
    end
    
    def validate_provider_business_rules(field_data)
      errors = []
      
      if field_data["provider_type"] == "MD" && field_data["license_number"].blank?
        errors << "Medical license number required"
      end
      
      ValidationResult.new(errors.empty?, errors)
    end
    
    def calculate_age(dob_string)
      return nil unless dob_string
      dob = Date.parse(dob_string)
      ((Date.current - dob) / 365.25).to_i
    rescue
      nil
    end
  end
  
  # Utility classes
  class ValidationResult
    attr_reader :success, :errors, :error_message
    
    def initialize(success, errors = [])
      @success = success
      @errors = errors.is_a?(Array) ? errors : [errors]
      @error_message = @errors.join("; ")
    end
    
    def success?
      @success
    end
  end
  
  class MockFileBotCompatibility
    def gets_diq(file, iens, fields, flags = "EI", target = "TARGET", msg = "MSG")
      # Mock traditional FileMan GETS^DIQ format
      {
        target => {
          file => {
            iens => parse_fields_to_diq_format(fields, mock_patient_data)
          }
        },
        msg => {}
      }
    end
    
    def update_die(wp, fda, flags = "", msg = "MSG")
      # Mock traditional FileMan UPDATE^DIE format
      { msg => {} } # Empty errors = success
    end
    
    def file_dicn(file, iens, name, dic = "DIC", y = "Y")
      # Mock traditional FileMan FILE^DICN format
      {
        y => {
          success: true,
          iens: rand(100..999),
          record: { message: "Entry filed" }
        }
      }
    end
    
    private
    
    def parse_fields_to_diq_format(fields, data)
      field_list = fields.split(";")
      result = {}
      
      field_list.each do |field|
        result[field] = {
          "E" => data[field] || "",
          "I" => data[field] || ""
        }
      end
      
      result
    end
    
    def mock_patient_data
      {
        ".01" => "SMITH,JOHN",
        ".02" => "M",
        ".03" => "1985-05-15",
        ".09" => "123456789"
      }
    end
  end
end

# Test configuration and helpers
module ActiveSupport
  class TestCase
    include FileBotTestHelper
    
    # JRuby-specific test setup
    def setup_jruby_environment
      # Ensure we're running on JRuby
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
      Rails.logger.warn "IRIS test connection failed: #{e.message}"
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
    
    # Mock factory methods
    def create_mock_filebot
      MockFileBot.new
    end
    
    def create_mock_data_dictionary
      MockDataDictionary.new
    end
    
    def create_mock_healthcare_validator
      MockHealthcareValidator.new
    end
    
    def create_mock_cross_reference_manager(iris_connection = nil)
      MockCrossReferenceManager.new(iris_connection)
    end
    
    def create_mock_business_rules_engine
      MockBusinessRulesEngine.new
    end
    
    def create_mock_compatibility_layer
      MockFileBotCompatibility.new
    end
    
    # Test data factories
    def valid_patient_data
      {
        "0.01" => "SMITH,JOHN",
        "0.02" => "M",
        "0.03" => "1985-05-15",
        "0.09" => "123456789",
        "0.11" => "123 MAIN STREET",
        "0.131" => "555-1234"
      }
    end
    
    def invalid_patient_data
      {
        "0.01" => "TEST,PATIENT", # Prohibited name
        "0.02" => "X",            # Invalid sex
        "0.03" => "invalid-date", # Invalid DOB
        "0.09" => "000000000"     # Invalid SSN
      }
    end
    
    def valid_provider_data
      {
        "0.01" => "PHYSICIAN,ATTENDING",
        "provider_type" => "MD",
        "license_number" => "12345",
        "dea_number" => "AB1234567"
      }
    end
    
    # Assertion helpers for FileBot tests
    def assert_filebot_success(result, message = nil)
      if result.respond_to?(:success?)
        assert result.success?, message || "Expected FileBot operation to succeed: #{result.errors}"
      else
        assert result[:success], message || "Expected FileBot operation to succeed: #{result[:errors]}"
      end
    end
    
    def assert_filebot_failure(result, expected_error = nil, message = nil)
      if result.respond_to?(:success?)
        refute result.success?, message || "Expected FileBot operation to fail"
        if expected_error
          assert_includes result.errors.join, expected_error
        end
      else
        refute result[:success], message || "Expected FileBot operation to fail"
        if expected_error
          assert_includes result[:errors].join, expected_error
        end
      end
    end
    
    def assert_cross_reference_built(cross_ref_manager, file_number, field_number = nil)
      built = cross_ref_manager.cross_references_built
      assert built.any? { |xref| xref[:file] == file_number },
             "Expected cross-reference to be built for file #{file_number}"
      
      if field_number
        assert built.any? { |xref| xref[:file] == file_number && xref[:fields].include?(field_number) },
               "Expected cross-reference to be built for field #{field_number} in file #{file_number}"
      end
    end
    
    # Performance testing helpers
    def benchmark_filebot_operation(description = "FileBot operation", &block)
      start_time = Time.current
      result = yield
      duration = Time.current - start_time
      
      Rails.logger.info "#{description} completed in #{duration}s"
      
      # Performance assertions
      assert duration < 1.0, "#{description} took too long: #{duration}s"
      
      result
    end
    
    # Healthcare-specific test helpers
    def create_adult_patient(age_years = 25)
      dob = (Date.current - age_years.years).strftime("%Y-%m-%d")
      valid_patient_data.merge("0.03" => dob)
    end
    
    def create_minor_patient(age_years = 16)
      dob = (Date.current - age_years.years).strftime("%Y-%m-%d")
      valid_patient_data.merge("0.03" => dob)
    end
    
    def create_veteran_patient
      valid_patient_data.merge(
        "veteran_flag" => "Y",
        "service_number" => "123456789"
      )
    end
    
    # Environment and setup helpers
    def skip_unless_iris_available
      skip "IRIS database not available for testing" unless iris_available_for_testing?
    end
    
    def skip_unless_jruby
      skip "JRuby required for FileBot tests" unless RUBY_PLATFORM == "java"
    end
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

# Extend Rails logger for FileBot testing
Rails.logger.info "FileBot Test Helper loaded - JRuby: #{RUBY_PLATFORM == 'java'}, IRIS Available: #{defined?(ActiveSupport::TestCase) && ActiveSupport::TestCase.new.iris_available_for_testing?}"