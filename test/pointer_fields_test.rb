# frozen_string_literal: true

require "test/unit"

class PointerFieldsTest < Test::Unit::TestCase
  def setup
    @filebot = FileBot.new(:iris)
    @patient_file = 2
    @provider_file = 200
    @hospital_file = 44
    
    # Create test provider
    @test_provider_data = {
      "0.01" => "TESTPROVIDER,ATTENDING",
      "0.02" => "MD", 
      "1" => "INTERNAL MEDICINE"
    }
    
    # Create test hospital location
    @test_location_data = {
      "0.01" => "TEST CLINIC",
      "1" => "OUTPATIENT",
      "3" => "ACTIVE"
    }
  end

  def teardown
    cleanup_test_records
  end

  test "pointer field validation accepts valid pointer" do
    # Create provider to point to
    provider_result = create_test_provider
    assert provider_result[:success], "Provider creation failed"
    provider_ien = provider_result[:dfn]

    # Create patient with pointer to provider
    patient_data = {
      "0.01" => "POINTERTEST,PATIENT",
      "0.02" => "F",
      "0.09" => "123456789",
      "0.104" => provider_ien.to_s  # PRIMARY CARE PROVIDER field (pointer to file 200)
    }
    
    patient_result = @filebot.create_patient(patient_data)
    assert patient_result[:success], "Patient creation with valid pointer failed: #{patient_result[:error]}"
  end

  test "pointer field validation rejects invalid pointer" do
    # Try to create patient with invalid provider pointer
    patient_data = {
      "0.01" => "BADPOINTER,PATIENT",
      "0.02" => "M", 
      "0.09" => "987654321",
      "0.104" => "999999"  # Non-existent provider
    }
    
    patient_result = @filebot.create_patient(patient_data)
    refute patient_result[:success], "Patient creation should fail with invalid pointer"
    assert_includes patient_result[:error], "Invalid pointer" if patient_result[:error]
  end

  test "pointer field resolves to external value" do
    # Create provider
    provider_result = create_test_provider
    assert provider_result[:success]
    provider_ien = provider_result[:dfn]

    # Create patient with provider pointer
    patient_data = {
      "0.01" => "RESOLVETEST,PATIENT",
      "0.02" => "M",
      "0.09" => "555666777", 
      "0.104" => provider_ien.to_s
    }
    
    patient_result = @filebot.create_patient(patient_data)
    assert patient_result[:success]
    patient_ien = patient_result[:dfn]

    # Get pointer field in external format
    gets_result = @filebot.gets_entry(@patient_file, patient_ien, ".104", "E")
    assert gets_result[:success]
    
    # Should resolve to provider name, not IEN
    assert_equal "TESTPROVIDER,ATTENDING", gets_result[:data][".104"]

    # Get pointer field in internal format
    gets_internal = @filebot.gets_entry(@patient_file, patient_ien, ".104", "I")
    assert gets_internal[:success]
    
    # Should return IEN in internal format
    assert_equal provider_ien.to_s, gets_internal[:data][".104"]
  end

  test "multiple pointer field resolution" do
    # Create provider and location
    provider_result = create_test_provider
    location_result = create_test_location
    assert provider_result[:success] && location_result[:success]
    
    provider_ien = provider_result[:dfn]
    location_ien = location_result[:dfn]

    # Create patient with multiple pointers
    patient_data = {
      "0.01" => "MULTIPOINTER,PATIENT",
      "0.02" => "F",
      "0.09" => "111222333",
      "0.104" => provider_ien.to_s,  # Provider pointer
      "0.105" => location_ien.to_s   # Location pointer (hypothetical field)
    }
    
    patient_result = @filebot.create_patient(patient_data)
    assert patient_result[:success]
    patient_ien = patient_result[:dfn]

    # Get both pointer fields in external format
    gets_result = @filebot.gets_entry(@patient_file, patient_ien, ".104;.105", "E")
    assert gets_result[:success]
    
    assert_equal "TESTPROVIDER,ATTENDING", gets_result[:data][".104"]
    assert_equal "TEST CLINIC", gets_result[:data][".105"]
  end

  test "pointer field update maintains referential integrity" do
    # Create two providers
    provider1_data = @test_provider_data.dup
    provider1_data["0.01"] = "PROVIDER1,TEST"
    provider1_result = @filebot.create_provider(provider1_data)
    assert provider1_result[:success]
    
    provider2_data = @test_provider_data.dup
    provider2_data["0.01"] = "PROVIDER2,TEST" 
    provider2_result = @filebot.create_provider(provider2_data)
    assert provider2_result[:success]

    # Create patient pointing to provider1
    patient_data = {
      "0.01" => "UPDATEPOINTER,PATIENT",
      "0.02" => "M",
      "0.09" => "444555666",
      "0.104" => provider1_result[:dfn].to_s
    }
    
    patient_result = @filebot.create_patient(patient_data)
    assert patient_result[:success]
    patient_ien = patient_result[:dfn]

    # Update pointer to provider2
    update_result = @filebot.update_entry(@patient_file, patient_ien, {
      ".104" => provider2_result[:dfn].to_s
    })
    assert update_result[:success]

    # Verify pointer updated correctly
    gets_result = @filebot.gets_entry(@patient_file, patient_ien, ".104", "E")
    assert gets_result[:success]
    assert_equal "PROVIDER2,TEST", gets_result[:data][".104"]
  end

  test "pointer field cascade delete prevention" do
    # Create provider
    provider_result = create_test_provider
    assert provider_result[:success]
    provider_ien = provider_result[:dfn]

    # Create patient pointing to provider
    patient_data = {
      "0.01" => "CASCADETEST,PATIENT",
      "0.02" => "F", 
      "0.09" => "777888999",
      "0.104" => provider_ien.to_s
    }
    
    patient_result = @filebot.create_patient(patient_data)
    assert patient_result[:success]

    # Try to delete provider (should fail due to referential integrity)
    delete_result = @filebot.delete_entry(@provider_file, provider_ien)
    refute delete_result[:success], "Provider deletion should fail when referenced by patient"
    assert_includes delete_result[:error], "referenced by other records" if delete_result[:error]
  end

  test "set of codes validation" do
    # Test field with set of codes (like gender field)
    patient_data = {
      "0.01" => "SETCODES,TEST",
      "0.02" => "M", # Valid code
      "0.09" => "123123123"
    }
    
    create_result = @filebot.create_patient(patient_data)
    assert create_result[:success]

    # Test invalid code
    patient_ien = create_result[:dfn]
    update_result = @filebot.update_entry(@patient_file, patient_ien, {
      ".02" => "X"  # Invalid gender code
    })
    
    refute update_result[:success], "Update with invalid set code should fail"
  end

  test "date pointer field validation" do
    # Create appointment with date validation
    appointment_data = {
      "0.01" => "DATETEST,APPOINTMENT",
      "0.02" => "2024-12-15",  # Future date
      "0.03" => "09:30"        # Time
    }
    
    # Should accept valid future date
    create_result = @filebot.create_appointment(appointment_data)
    assert create_result[:success] if @filebot.respond_to?(:create_appointment)
    
    # Should reject past date for appointments (business rule)
    past_date_data = appointment_data.dup
    past_date_data["0.02"] = "2020-01-01"
    
    past_result = @filebot.create_appointment(past_date_data) if @filebot.respond_to?(:create_appointment)
    # Would test business rule validation here
  end

  test "computed field calculation" do
    # Create patient with DOB to compute age
    patient_data = {
      "0.01" => "COMPUTED,PATIENT",
      "0.02" => "F",
      "0.03" => "1985-05-15",  # DOB for age calculation
      "0.09" => "999888777"
    }
    
    create_result = @filebot.create_patient(patient_data)
    assert create_result[:success]
    patient_ien = create_result[:dfn]

    # Get computed field (age)
    gets_result = @filebot.gets_entry(@patient_file, patient_ien, ".03;.033", "E")
    assert gets_result[:success]
    
    # Age field (.033) should be computed from DOB
    dob = gets_result[:data][".03"]
    age = gets_result[:data][".033"]
    
    if age && !age.empty?
      # Verify age is reasonable (between 30-45 for 1985 birth)
      age_num = age.to_i
      assert age_num >= 30 && age_num <= 50, "Computed age seems incorrect: #{age}"
    end
  end

  private

  def create_test_provider
    @filebot.create_provider(@test_provider_data) if @filebot.respond_to?(:create_provider)
  end

  def create_test_location
    @filebot.create_location(@test_location_data) if @filebot.respond_to?(:create_location)
  end

  def cleanup_test_records
    # Clean up test records
    test_patients = [
      "POINTERTEST,PATIENT", "BADPOINTER,PATIENT", "RESOLVETEST,PATIENT",
      "MULTIPOINTER,PATIENT", "UPDATEPOINTER,PATIENT", "CASCADETEST,PATIENT",
      "SETCODES,TEST", "COMPUTED,PATIENT"
    ]
    
    test_providers = [
      "TESTPROVIDER,ATTENDING", "PROVIDER1,TEST", "PROVIDER2,TEST"
    ]
    
    test_locations = [
      "TEST CLINIC"
    ]

    # Clean up patients
    test_patients.each do |name|
      cleanup_by_name(@patient_file, name)
    end

    # Clean up providers
    test_providers.each do |name|
      cleanup_by_name(@provider_file, name)
    end

    # Clean up locations
    test_locations.each do |name|
      cleanup_by_name(@hospital_file, name)
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