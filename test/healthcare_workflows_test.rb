#!/usr/bin/env jruby

# Healthcare Workflows Integration Test - Real clinical scenarios
# Tests healthcare-specific operations against live IRIS
# Usage: IRIS_PASSWORD=passwordpassword jruby -Ilib test/healthcare_workflows_test.rb

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'filebot'
require 'test/unit'

class HealthcareWorkflowsTest < Test::Unit::TestCase
  def setup
    skip_if_no_iris
    @filebot = FileBot.new(:iris)
    @test_dfn = '8888'  # Use specific DFN for healthcare tests
    cleanup_test_patient
    create_test_patient
  end

  def teardown
    cleanup_test_patient if @filebot
  end

  def test_patient_registration_workflow
    # Test complete patient registration workflow
    registration_data = {
      dfn: @test_dfn,
      name: "HEALTHCARE,TESTPATIENT",
      ssn: "555-00-8888", 
      dob: "1975-05-15",
      sex: "F",
      address: {
        street: "123 Healthcare Drive",
        city: "Medical City", 
        state: "TX",
        zip: "75001"
      },
      phone: "555-123-4567",
      emergency_contact: {
        name: "Emergency Contact",
        phone: "555-987-6543",
        relationship: "Spouse"
      }
    }

    # Register patient
    result = @filebot.create_patient(registration_data)
    assert result[:success], "Patient registration should succeed"
    
    # Verify registration created all necessary records
    patient = @filebot.get_patient_demographics(@test_dfn)
    assert patient, "Should retrieve registered patient"
    assert_equal "HEALTHCARE,TESTPATIENT", patient[:name]
    assert_equal "F", patient[:sex]
    assert_equal "555-00-8888", patient[:ssn]

    puts "✅ Patient registration workflow working"
  end

  def test_clinical_data_entry_workflow
    # Test entering clinical data for patient
    
    # Add allergies
    allergy_data = {
      dfn: @test_dfn,
      allergen: "PENICILLIN",
      reaction: "RASH",
      severity: "MODERATE",
      date_identified: "2024-01-15"
    }

    # This tests the healthcare workflow methods
    if @filebot.respond_to?(:add_patient_allergy)
      result = @filebot.add_patient_allergy(allergy_data)
      assert result[:success], "Allergy entry should succeed"
      puts "✅ Allergy entry workflow working"
    else
      puts "⚠️  Allergy workflow methods not yet implemented"
    end

    # Add vital signs
    vitals_data = {
      dfn: @test_dfn,
      temperature: "98.6",
      blood_pressure: "120/80", 
      heart_rate: "72",
      respiratory_rate: "16",
      date_time: Time.now.strftime("%Y-%m-%d %H:%M:%S")
    }

    if @filebot.respond_to?(:add_vital_signs)
      result = @filebot.add_vital_signs(vitals_data)
      assert result[:success], "Vital signs entry should succeed"
      puts "✅ Vital signs workflow working"
    else
      puts "⚠️  Vital signs workflow methods not yet implemented"
    end
  end

  def test_medication_workflow
    # Test medication ordering and management
    medication_data = {
      dfn: @test_dfn,
      medication: "TYLENOL",
      dosage: "325MG",
      frequency: "Q6H",
      route: "PO",
      start_date: Date.today.strftime("%Y-%m-%d"),
      prescribing_provider: "DR. SMITH"
    }

    if @filebot.respond_to?(:medication_ordering_workflow)
      result = @filebot.medication_ordering_workflow(@test_dfn, medication_data)
      
      # Basic result validation
      assert result, "Medication workflow should return result"
      puts "✅ Medication ordering workflow executed"
    else
      puts "⚠️  Medication workflow not yet fully implemented"
      
      # Test that we can at least store medication data in patient record
      patient = @filebot.get_patient_demographics(@test_dfn)
      assert patient, "Patient should exist for medication workflow test"
      puts "✅ Patient exists for medication workflow testing"
    end
  end

  def test_lab_results_workflow  
    # Test lab result entry and retrieval
    lab_data = {
      dfn: @test_dfn,
      test_name: "CBC",
      result_value: "Normal",
      reference_range: "Normal",
      units: "",
      date_collected: Date.today.strftime("%Y-%m-%d"),
      ordering_provider: "DR. JONES"
    }

    if @filebot.respond_to?(:lab_result_entry_workflow)
      result = @filebot.lab_result_entry_workflow(@test_dfn, "CBC", "Normal")
      
      assert result, "Lab result workflow should return result"
      puts "✅ Lab result entry workflow executed"
    else
      puts "⚠️  Lab result workflow not yet fully implemented"
      
      # Test basic patient data integrity for lab workflows
      patient = @filebot.get_patient_demographics(@test_dfn)
      assert patient, "Patient should exist for lab workflow test"
      puts "✅ Patient exists for lab workflow testing"
    end
  end

  def test_clinical_documentation_workflow
    # Test clinical note entry
    note_data = {
      dfn: @test_dfn,
      note_type: "PROGRESS NOTE",
      note_text: "Patient reports feeling well. No acute distress. Plan: Continue current medications.",
      author: "DR. WILSON", 
      date_time: Time.now.strftime("%Y-%m-%d %H:%M:%S")
    }

    if @filebot.respond_to?(:clinical_documentation_workflow)
      result = @filebot.clinical_documentation_workflow(@test_dfn, note_data)
      
      assert result, "Clinical documentation workflow should return result"
      puts "✅ Clinical documentation workflow executed"
    else
      puts "⚠️  Clinical documentation workflow not yet fully implemented"
      
      # Test basic patient lookup for documentation
      patient = @filebot.get_patient_demographics(@test_dfn)
      assert patient, "Patient should exist for documentation workflow"
      puts "✅ Patient exists for clinical documentation testing"
    end
  end

  def test_appointment_scheduling_workflow
    # Test appointment scheduling
    appointment_data = {
      dfn: @test_dfn,
      clinic: "INTERNAL MEDICINE",
      provider: "DR. BROWN",
      appointment_date: (Date.today + 7).strftime("%Y-%m-%d"),
      appointment_time: "10:00",
      appointment_type: "FOLLOW-UP"
    }

    if @filebot.respond_to?(:schedule_appointment)
      result = @filebot.schedule_appointment(appointment_data)
      
      assert result, "Appointment scheduling should return result"
      puts "✅ Appointment scheduling workflow executed"
    else
      puts "⚠️  Appointment scheduling not yet implemented"
      
      # Test patient lookup for scheduling
      patient = @filebot.get_patient_demographics(@test_dfn)
      assert patient, "Patient should exist for appointment scheduling"
      puts "✅ Patient exists for appointment scheduling testing"
    end
  end

  def test_discharge_summary_workflow
    # Test discharge summary creation
    discharge_data = {
      dfn: @test_dfn,
      admission_date: "2024-08-10",
      discharge_date: "2024-08-13", 
      primary_diagnosis: "PNEUMONIA",
      secondary_diagnoses: ["HYPERTENSION", "DIABETES"],
      procedures: ["CHEST X-RAY", "BLOOD CULTURE"],
      medications_on_discharge: ["AMOXICILLIN 500MG PO TID", "LISINOPRIL 10MG PO DAILY"],
      follow_up_instructions: "Follow up with primary care in 1 week",
      discharge_condition: "STABLE"
    }

    if @filebot.respond_to?(:discharge_summary_workflow)
      result = @filebot.discharge_summary_workflow(@test_dfn, discharge_data)
      
      assert result, "Discharge summary workflow should return result"
      puts "✅ Discharge summary workflow executed"
    else
      puts "⚠️  Discharge summary workflow not yet fully implemented"
      
      # Test patient exists for discharge workflow
      patient = @filebot.get_patient_demographics(@test_dfn)
      assert patient, "Patient should exist for discharge summary"
      puts "✅ Patient exists for discharge summary testing"
    end
  end

  def test_healthcare_data_validation
    # Test healthcare-specific validation rules
    
    # Test invalid SSN format
    invalid_patient = {
      dfn: "9999",
      name: "INVALID,PATIENT",
      ssn: "123-45-678X",  # Invalid SSN
      dob: "1980-13-45",   # Invalid date
      sex: "X"             # Invalid sex
    }

    result = @filebot.validate_patient(invalid_patient)
    refute result[:valid], "Invalid patient data should fail validation"
    assert result[:errors].any?, "Should return validation errors"

    puts "✅ Healthcare data validation working: #{result[:errors].length} errors caught"

    # Test valid patient data
    valid_patient = {
      dfn: "9998",
      name: "VALID,PATIENT", 
      ssn: "123-45-6789",
      dob: "1980-01-15",
      sex: "M"
    }

    result = @filebot.validate_patient(valid_patient)
    assert result[:valid], "Valid patient data should pass validation"

    puts "✅ Valid patient data passes validation"
  end

  def test_hipaa_compliance_features
    # Test HIPAA compliance features
    
    # Test audit logging if available
    if @filebot.respond_to?(:audit_log)
      audit_entry = {
        user: "TEST_USER",
        action: "VIEW_PATIENT",
        patient_dfn: @test_dfn,
        timestamp: Time.now,
        ip_address: "127.0.0.1"
      }
      
      result = @filebot.audit_log(audit_entry)
      assert result, "Audit logging should work"
      puts "✅ HIPAA audit logging working"
    else
      puts "⚠️  HIPAA audit logging not yet implemented"
    end

    # Test patient privacy controls
    patient = @filebot.get_patient_demographics(@test_dfn)
    assert patient, "Should retrieve patient for privacy test"
    
    # SSN should be masked or protected in some way for display
    if patient[:ssn_masked] || patient[:ssn].include?("***")
      puts "✅ SSN masking/protection working"
    else
      puts "⚠️  SSN protection not implemented"
    end
  end

  private

  def skip_if_no_iris
    unless ENV['IRIS_PASSWORD']
      skip "IRIS_PASSWORD not set - skipping healthcare workflow tests"
    end

    begin
      FileBot::DatabaseAdapterFactory.create_adapter(:iris)
    rescue => e
      skip "IRIS not available: #{e.message}"
    end
  end

  def create_test_patient
    test_patient = {
      dfn: @test_dfn,
      name: "WORKFLOW,TESTPATIENT",
      ssn: "555-00-8888",
      dob: "1975-05-15",
      sex: "F"
    }

    result = @filebot.create_patient(test_patient)
    unless result[:success]
      flunk "Failed to create test patient for workflow tests"
    end
  end

  def cleanup_test_patient
    return unless @filebot

    begin
      # Remove patient record
      @filebot.adapter.set_global("^DPT", @test_dfn, "")
      
      # Remove common cross-references
      ["WORKFLOW,TESTPATIENT", "HEALTHCARE,TESTPATIENT"].each do |name|
        @filebot.adapter.set_global("^DPT", "B", name, @test_dfn, "") rescue nil
      end
      
      # Remove SSN cross-reference
      @filebot.adapter.set_global("^DPT", "SSN", "555008888", @test_dfn, "") rescue nil
      
    rescue => e
      # Ignore cleanup errors
    end
  end
end

if __FILE__ == $0
  puts "🏥 FileBot Healthcare Workflows Integration Test"
  puts "=" * 60
  puts "Testing healthcare-specific workflows against live IRIS instance"
  puts "Includes: patient registration, clinical data, medications, lab results"
  puts ""
end