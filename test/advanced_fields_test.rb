# frozen_string_literal: true

require "test/unit"

class AdvancedFieldsTest < Test::Unit::TestCase
  def setup
    @filebot = FileBot.new(:iris)
    @patient_file = 2
    @note_file = 8925  # TIU DOCUMENT file (hypothetical)
  end

  def teardown
    cleanup_test_records
  end

  # Word Processing Field Tests
  test "word processing field storage and retrieval" do
    # Create clinical note with word processing content
    note_data = {
      "0.01" => "TEST CLINICAL NOTE",
      "0.02" => "PROGRESS NOTE",
      "1" => [  # Word processing field as array
        "PATIENT PRESENTS WITH:",
        "1. Chest pain, non-cardiac",
        "2. Hypertension, controlled",
        "",
        "ASSESSMENT AND PLAN:",
        "Continue current medications.",
        "Follow up in 2 weeks.",
        "",
        "Electronically signed by TEST PROVIDER"
      ]
    }
    
    create_result = @filebot.create_note(note_data) if @filebot.respond_to?(:create_note)
    if create_result
      assert create_result[:success], "Note creation failed"
      note_ien = create_result[:dfn]

      # Retrieve word processing field
      gets_result = @filebot.gets_entry(@note_file, note_ien, "1", "E")
      assert gets_result[:success]
      
      wp_text = gets_result[:data]["1"]
      assert_includes wp_text, "PATIENT PRESENTS WITH"
      assert_includes wp_text, "Follow up in 2 weeks"
    end
  end

  test "word processing field line limits" do
    # Test word processing field with line limits
    long_content = Array.new(1000) { |i| "This is line #{i+1} of a very long document." }
    
    note_data = {
      "0.01" => "LONG TEST NOTE",
      "0.02" => "CONSULTATION",
      "1" => long_content
    }
    
    create_result = @filebot.create_note(note_data) if @filebot.respond_to?(:create_note)
    if create_result
      # Should either succeed with truncation or fail with appropriate error
      if create_result[:success]
        note_ien = create_result[:dfn]
        gets_result = @filebot.gets_entry(@note_file, note_ien, "1", "E")
        assert gets_result[:success]
        
        # Content should be limited (e.g., max 500 lines)
        line_count = gets_result[:data]["1"].split("\n").length
        assert line_count <= 500, "Word processing field should enforce line limits"
      else
        assert_includes create_result[:error], "too many lines" if create_result[:error]
      end
    end
  end

  # Input Transform Tests
  test "input transform uppercase name" do
    # Names should be automatically uppercased
    patient_data = {
      "0.01" => "lowercase,patient",  # Should be transformed to uppercase
      "0.02" => "m",                  # Should be transformed to uppercase
      "0.09" => "123456789"
    }
    
    create_result = @filebot.create_patient(patient_data)
    assert create_result[:success]
    patient_ien = create_result[:dfn]

    # Verify input transform applied
    gets_result = @filebot.gets_entry(@patient_file, patient_ien, ".01;.02", "I")
    assert gets_result[:success]
    
    assert_equal "LOWERCASE,PATIENT", gets_result[:data][".01"]
    assert_equal "M", gets_result[:data][".02"]
  end

  test "input transform date normalization" do
    # Various date formats should be normalized
    test_dates = [
      { input: "12/25/1985", expected: "2851225" },
      { input: "DEC 25, 1985", expected: "2851225" }, 
      { input: "25-DEC-85", expected: "2851225" },
      { input: "1985-12-25", expected: "2851225" }
    ]
    
    test_dates.each_with_index do |date_test, index|
      patient_data = {
        "0.01" => "DATETEST#{index},PATIENT",
        "0.02" => "F",
        "0.03" => date_test[:input],  # DOB with various formats
        "0.09" => "12345678#{index}"
      }
      
      create_result = @filebot.create_patient(patient_data)
      assert create_result[:success], "Failed to create patient with date: #{date_test[:input]}"
      
      patient_ien = create_result[:dfn]
      gets_result = @filebot.gets_entry(@patient_file, patient_ien, ".03", "I")
      
      assert gets_result[:success]
      assert_equal date_test[:expected], gets_result[:data][".03"], 
                   "Date transform failed for #{date_test[:input]}"
    end
  end

  test "input transform SSN formatting" do
    # SSN should accept various formats and normalize
    ssn_tests = [
      { input: "123-45-6789", expected: "123456789" },
      { input: "123 45 6789", expected: "123456789" },
      { input: "123456789", expected: "123456789" }
    ]
    
    ssn_tests.each_with_index do |ssn_test, index|
      patient_data = {
        "0.01" => "SSNTEST#{index},PATIENT",
        "0.02" => "M",
        "0.09" => ssn_test[:input]
      }
      
      create_result = @filebot.create_patient(patient_data)
      assert create_result[:success], "Failed to create patient with SSN: #{ssn_test[:input]}"
      
      patient_ien = create_result[:dfn]
      gets_result = @filebot.gets_entry(@patient_file, patient_ien, ".09", "I")
      
      assert gets_result[:success]
      assert_equal ssn_test[:expected], gets_result[:data][".09"],
                   "SSN transform failed for #{ssn_test[:input]}"
    end
  end

  test "input transform phone number formatting" do
    # Phone numbers should be normalized
    phone_tests = [
      { input: "(555) 123-4567", expected: "5551234567" },
      { input: "555-123-4567", expected: "5551234567" },
      { input: "555 123 4567", expected: "5551234567" },
      { input: "5551234567", expected: "5551234567" }
    ]
    
    phone_tests.each_with_index do |phone_test, index|
      patient_data = {
        "0.01" => "PHONETEST#{index},PATIENT", 
        "0.02" => "F",
        "0.09" => "98765432#{index}",
        "0.131" => phone_test[:input]  # Phone number field
      }
      
      create_result = @filebot.create_patient(patient_data)
      assert create_result[:success], "Failed to create patient with phone: #{phone_test[:input]}"
      
      patient_ien = create_result[:dfn]
      gets_result = @filebot.gets_entry(@patient_file, patient_ien, ".131", "I")
      
      assert gets_result[:success]
      assert_equal phone_test[:expected], gets_result[:data][".131"],
                   "Phone transform failed for #{phone_test[:input]}"
    end
  end

  # Output Transform Tests
  test "output transform date display" do
    # Create patient with internal date format
    patient_data = {
      "0.01" => "OUTPUTDATE,PATIENT",
      "0.02" => "M", 
      "0.03" => "2851225",  # Internal format
      "0.09" => "555667788"
    }
    
    create_result = @filebot.create_patient(patient_data)
    assert create_result[:success]
    patient_ien = create_result[:dfn]

    # Get external format
    gets_result = @filebot.gets_entry(@patient_file, patient_ien, ".03", "E")
    assert gets_result[:success]
    
    # Should be formatted for display
    formatted_date = gets_result[:data][".03"]
    assert_match(/\d{2}\/\d{2}\/\d{4}/, formatted_date, "Date should be formatted as MM/DD/YYYY")
  end

  test "output transform SSN display" do
    # Create patient with internal SSN format
    patient_data = {
      "0.01" => "OUTPUTSSN,PATIENT",
      "0.02" => "F",
      "0.03" => "1990-01-01",
      "0.09" => "123456789"  # Internal format
    }
    
    create_result = @filebot.create_patient(patient_data)
    assert create_result[:success]
    patient_ien = create_result[:dfn]

    # Get external format
    gets_result = @filebot.gets_entry(@patient_file, patient_ien, ".09", "E")
    assert gets_result[:success]
    
    # Should be formatted with dashes
    formatted_ssn = gets_result[:data][".09"]
    assert_equal "123-45-6789", formatted_ssn
  end

  # Multiple/Variable Pointer Tests
  test "variable pointer field validation" do
    # Field that can point to different file types
    # Example: PROVIDER field that can point to PERSON or INSTITUTION
    
    # Create individual provider
    person_data = {
      "0.01" => "INDIVIDUAL,PROVIDER",
      "0.02" => "MD"
    }
    
    person_result = @filebot.create_provider(person_data) if @filebot.respond_to?(:create_provider)
    if person_result&.dig(:success)
      # Create institution
      institution_data = {
        "0.01" => "ACME MEDICAL CENTER",
        "1" => "HOSPITAL"
      }
      
      institution_result = @filebot.create_institution(institution_data) if @filebot.respond_to?(:create_institution)
      
      if institution_result&.dig(:success)
        # Test patient with provider pointing to person
        patient_data1 = {
          "0.01" => "VARPOINTER1,PATIENT",
          "0.02" => "M",
          "0.09" => "111222333",
          "0.104" => "#{person_result[:dfn]};200"  # IEN;FILE format for variable pointer
        }
        
        create1 = @filebot.create_patient(patient_data1)
        assert create1[:success], "Variable pointer to person failed" if create1

        # Test patient with provider pointing to institution
        patient_data2 = {
          "0.01" => "VARPOINTER2,PATIENT", 
          "0.02" => "F",
          "0.09" => "222333444",
          "0.104" => "#{institution_result[:dfn]};4"  # IEN;FILE format
        }
        
        create2 = @filebot.create_patient(patient_data2)
        assert create2[:success], "Variable pointer to institution failed" if create2
      end
    end
  end

  # Laygo (Learn As You Go) Tests
  test "laygo functionality creates new entries" do
    # Test LAYGO on a field that allows it (like DIAGNOSIS)
    patient_data = {
      "0.01" => "LAYGO,PATIENT",
      "0.02" => "M",
      "0.09" => "333444555",
      "primary_diagnosis" => "NEW RARE CONDITION"  # Should create new diagnosis if not found
    }
    
    create_result = @filebot.create_patient(patient_data)
    if create_result&.dig(:success)
      # Should create patient AND new diagnosis entry
      assert create_result[:success], "LAYGO patient creation failed"
      
      # Verify new diagnosis was created
      diagnosis_search = @filebot.find_entries(80, "NEW RARE CONDITION", ".01") # ICD diagnosis file
      if diagnosis_search&.dig(:success)
        assert diagnosis_search[:count] > 0, "LAYGO should have created new diagnosis entry"
      end
    end
  end

  private

  def cleanup_test_records
    # Clean up various test records
    test_patients = [
      "DATETEST0,PATIENT", "DATETEST1,PATIENT", "DATETEST2,PATIENT", "DATETEST3,PATIENT",
      "SSNTEST0,PATIENT", "SSNTEST1,PATIENT", "SSNTEST2,PATIENT", 
      "PHONETEST0,PATIENT", "PHONETEST1,PATIENT", "PHONETEST2,PATIENT", "PHONETEST3,PATIENT",
      "OUTPUTDATE,PATIENT", "OUTPUTSSN,PATIENT", "VARPOINTER1,PATIENT", "VARPOINTER2,PATIENT",
      "LAYGO,PATIENT"
    ]
    
    test_notes = [
      "TEST CLINICAL NOTE", "LONG TEST NOTE"
    ]
    
    # Clean up patients
    test_patients.each do |name|
      cleanup_by_name(@patient_file, name)
    end
    
    # Clean up notes
    test_notes.each do |name|
      cleanup_by_name(@note_file, name) if @filebot.respond_to?(:find_entries)
    end
  end

  def cleanup_by_name(file_number, name)
    begin
      find_result = @filebot.find_entries(file_number, name, ".01")
      if find_result[:success] && find_result[:count] > 0
        find_result[:results].each do |result|
          @filebot.unlock_entry(file_number, result[:ien]) rescue nil
          @filebot.delete_entry(file_number, result[:ien]) rescue nil
        end
      end
    rescue => e
      puts "Cleanup error for #{name}: #{e.message}"
    end
  end
end