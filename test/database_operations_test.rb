# frozen_string_literal: true

require "test/unit"

class DatabaseOperationsTest < Test::Unit::TestCase
  def setup
    @filebot = FileBot.new(:iris)
    @test_file_number = 2 # Patient file
    @test_patient_data = {
      "0.01" => "DBTEST,PATIENT", 
      "0.02" => "M",
      "0.03" => "1985-05-15",
      "0.09" => "123456789",
      "0.11" => "123 DB TEST STREET",
      "0.131" => "555-TEST"
    }
  end

  def teardown
    # Clean up test data
    cleanup_test_records
  end

  # FIND^DIC functionality tests
  test "find_entries by name returns matching patients" do
    # Create test patient
    create_result = create_test_patient
    assert create_result[:success], "Test patient creation failed"
    dfn = create_result[:dfn]

    # Find by partial name match
    find_result = @filebot.find_entries(@test_file_number, "DBTEST", ".01")
    
    assert find_result[:success], "Find operation failed: #{find_result[:error]}"
    assert find_result[:count] > 0, "No patients found"
    
    found_patient = find_result[:results].find { |r| r[:ien] == dfn }
    assert_not_nil found_patient, "Test patient not found in results"
    assert_equal "DBTEST,PATIENT", found_patient[:name]
  end

  test "find_entries by SSN returns correct patient" do
    # Create test patient
    create_result = create_test_patient
    assert create_result[:success]
    dfn = create_result[:dfn]

    # Find by SSN
    find_result = @filebot.find_entries(@test_file_number, "123456789", ".09")
    
    assert find_result[:success]
    assert find_result[:count] > 0
    
    found_patient = find_result[:results].find { |r| r[:ien] == dfn }
    assert_not_nil found_patient
    assert_equal "123456789", found_patient[:search_value]
  end

  test "find_entries respects max_results limit" do
    # Create multiple test patients
    3.times do |i|
      patient_data = @test_patient_data.dup
      patient_data["0.01"] = "DBTEST#{i},PATIENT"
      patient_data["0.09"] = "12345678#{i}"
      @filebot.create_patient(patient_data)
    end

    # Find with limit of 2
    find_result = @filebot.find_entries(@test_file_number, "DBTEST", ".01", nil, 2)
    
    assert find_result[:success]
    assert find_result[:count] <= 2, "Results exceeded max_results limit"
  end

  test "find_entries handles no matches gracefully" do
    find_result = @filebot.find_entries(@test_file_number, "NONEXISTENT", ".01")
    
    assert find_result[:success]
    assert_equal 0, find_result[:count]
    assert_empty find_result[:results]
  end

  # LIST^DIC functionality tests  
  test "list_entries returns patient list" do
    # Create test patients
    2.times do |i|
      patient_data = @test_patient_data.dup
      patient_data["0.01"] = "LISTTEST#{i},PATIENT"
      patient_data["0.09"] = "87654321#{i}"
      @filebot.create_patient(patient_data)
    end

    # List entries
    list_result = @filebot.list_entries(@test_file_number, "", ".01;.02", 10)
    
    assert list_result[:success], "List operation failed: #{list_result[:error]}"
    assert list_result[:count] > 0, "No entries found"
    
    # Check that results have requested fields
    list_result[:results].each do |entry|
      assert entry[:fields].key?(".01"), "Missing .01 field"
      assert entry[:fields].key?(".02"), "Missing .02 field"
    end
  end

  test "list_entries with screening" do
    # Create male and female patients
    male_data = @test_patient_data.dup
    male_data["0.01"] = "SCREENTEST,MALE"
    male_data["0.02"] = "M"
    
    female_data = @test_patient_data.dup
    female_data["0.01"] = "SCREENTEST,FEMALE"
    female_data["0.02"] = "F"
    female_data["0.09"] = "987654321"
    
    @filebot.create_patient(male_data)
    @filebot.create_patient(female_data)

    # List males only
    list_result = @filebot.list_entries(@test_file_number, "", ".01;.02", 10, "M")
    
    assert list_result[:success]
    
    # All results should be male
    list_result[:results].each do |entry|
      assert_equal "M", entry[:fields][".02"], "Non-male patient in screened results"
    end
  end

  test "list_entries respects max_results" do
    # Create multiple patients
    5.times do |i|
      patient_data = @test_patient_data.dup
      patient_data["0.01"] = "MAXTEST#{i},PATIENT"
      patient_data["0.09"] = "55544433#{i}"
      @filebot.create_patient(patient_data)
    end

    # List with limit of 3
    list_result = @filebot.list_entries(@test_file_number, "", ".01", 3)
    
    assert list_result[:success]
    assert list_result[:count] <= 3, "Results exceeded max_results limit"
  end

  # DELETE^DIC functionality tests
  test "delete_entry removes patient successfully" do
    # Create test patient
    create_result = create_test_patient
    assert create_result[:success]
    dfn = create_result[:dfn]

    # Verify patient exists
    gets_result = @filebot.gets_entry(@test_file_number, dfn, ".01")
    assert gets_result[:success], "Patient should exist before deletion"

    # Delete patient
    delete_result = @filebot.delete_entry(@test_file_number, dfn)
    
    assert delete_result[:success], "Delete failed: #{delete_result[:error]}"
    assert_equal dfn, delete_result[:deleted_ien]

    # Verify patient is deleted
    gets_result = @filebot.gets_entry(@test_file_number, dfn, ".01")
    refute gets_result[:success], "Patient should not exist after deletion"
  end

  test "delete_entry handles non-existent entry" do
    delete_result = @filebot.delete_entry(@test_file_number, 999999)
    
    refute delete_result[:success]
    assert_includes delete_result[:error], "Entry not found"
  end

  # Record locking tests
  test "lock_entry and unlock_entry work correctly" do
    # Create test patient
    create_result = create_test_patient
    assert create_result[:success]
    dfn = create_result[:dfn]

    # Lock entry
    lock_result = @filebot.lock_entry(@test_file_number, dfn)
    
    assert lock_result[:success], "Lock failed: #{lock_result[:error]}"
    assert_not_nil lock_result[:locked_by]

    # Try to lock again (should fail)
    lock_result2 = @filebot.lock_entry(@test_file_number, dfn)
    refute lock_result2[:success], "Double lock should fail"
    assert_includes lock_result2[:error], "locked by another user"

    # Unlock entry
    unlock_result = @filebot.unlock_entry(@test_file_number, dfn)
    assert unlock_result[:success], "Unlock failed"

    # Lock should now work again
    lock_result3 = @filebot.lock_entry(@test_file_number, dfn)
    assert lock_result3[:success], "Lock after unlock should work"
    
    # Cleanup
    @filebot.unlock_entry(@test_file_number, dfn)
  end

  test "lock_entry expires old locks" do
    # Create test patient
    create_result = create_test_patient
    assert create_result[:success]
    dfn = create_result[:dfn]

    # Mock an expired lock by setting timeout to 0
    lock_result = @filebot.lock_entry(@test_file_number, dfn, 0)
    assert lock_result[:success]

    # Wait briefly then try to lock again
    sleep(0.1)
    lock_result2 = @filebot.lock_entry(@test_file_number, dfn, 30)
    assert lock_result2[:success], "Expired lock should be overrideable"
    
    # Cleanup
    @filebot.unlock_entry(@test_file_number, dfn)
  end

  # GETS^DIQ functionality tests
  test "gets_entry returns formatted field data" do
    # Create test patient
    create_result = create_test_patient
    assert create_result[:success]
    dfn = create_result[:dfn]

    # Get internal format
    gets_result = @filebot.gets_entry(@test_file_number, dfn, ".01;.02;.09", "I")
    
    assert gets_result[:success], "Gets failed: #{gets_result[:error]}"
    assert_equal "DBTEST,PATIENT", gets_result[:data][".01"]
    assert_equal "M", gets_result[:data][".02"]
    assert_equal "123456789", gets_result[:data][".09"]

    # Get external format
    gets_result_ext = @filebot.gets_entry(@test_file_number, dfn, ".02;.09", "E")
    
    assert gets_result_ext[:success]
    assert_equal "MALE", gets_result_ext[:data][".02"]
    assert_equal "123-45-6789", gets_result_ext[:data][".09"]
  end

  test "gets_entry handles non-existent entry" do
    gets_result = @filebot.gets_entry(@test_file_number, 999999, ".01")
    
    refute gets_result[:success]
    assert_includes gets_result[:error], "Entry not found"
  end

  # UPDATE^DIE functionality tests
  test "update_entry modifies patient data" do
    # Create test patient
    create_result = create_test_patient
    assert create_result[:success]
    dfn = create_result[:dfn]

    # Update patient data
    update_data = {
      ".01" => "UPDATED,PATIENT",
      ".131" => "555-UPDATED"
    }
    
    update_result = @filebot.update_entry(@test_file_number, dfn, update_data)
    assert update_result[:success], "Update failed: #{update_result[:error]}"

    # Verify changes
    gets_result = @filebot.gets_entry(@test_file_number, dfn, ".01;.131", "I")
    assert gets_result[:success]
    assert_equal "UPDATED,PATIENT", gets_result[:data][".01"]
    assert_equal "555-UPDATED", gets_result[:data][".131"]
  end

  test "update_entry handles validation errors" do
    # Create test patient
    create_result = create_test_patient
    assert create_result[:success]
    dfn = create_result[:dfn]

    # Try to update with invalid data
    update_data = {
      ".01" => "", # Name required
      ".02" => "X"  # Invalid gender
    }
    
    update_result = @filebot.update_entry(@test_file_number, dfn, update_data)
    refute update_result[:success], "Update with invalid data should fail"
    assert_not_empty update_result[:errors] if update_result[:errors]
  end

  test "update_entry handles non-existent entry" do
    update_data = { ".01" => "NONEXISTENT,PATIENT" }
    update_result = @filebot.update_entry(@test_file_number, 999999, update_data)
    
    refute update_result[:success]
    assert_includes update_result[:error], "Entry not found"
  end

  # Cross-reference integrity tests
  test "database operations maintain cross-reference integrity" do
    # Create patient with specific name
    patient_data = @test_patient_data.dup
    patient_data["0.01"] = "CROSSREF,TEST"
    
    create_result = @filebot.create_patient(patient_data)
    assert create_result[:success]
    dfn = create_result[:dfn]

    # Verify we can find by name
    find_result = @filebot.find_entries(@test_file_number, "CROSSREF", ".01")
    assert find_result[:success]
    assert find_result[:count] > 0

    # Update name
    update_result = @filebot.update_entry(@test_file_number, dfn, { ".01" => "NEWNAME,TEST" })
    assert update_result[:success]

    # Old name should not be findable
    find_old = @filebot.find_entries(@test_file_number, "CROSSREF", ".01")
    assert_equal 0, find_old[:count], "Old name still findable after update"

    # New name should be findable
    find_new = @filebot.find_entries(@test_file_number, "NEWNAME", ".01") 
    assert find_new[:count] > 0, "New name not findable after update"

    # Delete patient
    delete_result = @filebot.delete_entry(@test_file_number, dfn)
    assert delete_result[:success]

    # Name should no longer be findable
    find_deleted = @filebot.find_entries(@test_file_number, "NEWNAME", ".01")
    assert_equal 0, find_deleted[:count], "Name still findable after deletion"
  end

  # Performance tests
  test "database operations perform within acceptable limits" do
    # Create test data
    create_result = create_test_patient
    assert create_result[:success]
    dfn = create_result[:dfn]

    # Test find performance
    find_start = Time.current
    find_result = @filebot.find_entries(@test_file_number, "DBTEST", ".01")
    find_duration = Time.current - find_start
    
    assert find_result[:success]
    assert find_duration < 0.1, "Find operation too slow: #{find_duration}s"

    # Test gets performance 
    gets_start = Time.current
    gets_result = @filebot.gets_entry(@test_file_number, dfn, ".01;.02;.03;.09")
    gets_duration = Time.current - gets_start
    
    assert gets_result[:success]
    assert gets_duration < 0.05, "Gets operation too slow: #{gets_duration}s"

    # Test update performance
    update_start = Time.current
    update_result = @filebot.update_entry(@test_file_number, dfn, { ".131" => "555-PERF" })
    update_duration = Time.current - update_start
    
    assert update_result[:success]
    assert update_duration < 0.1, "Update operation too slow: #{update_duration}s"
  end

  private

  def create_test_patient
    @filebot.create_patient(@test_patient_data)
  end

  def cleanup_test_records
    # Clean up any test records created during tests
    test_names = [
      "DBTEST,PATIENT", "LISTTEST0,PATIENT", "LISTTEST1,PATIENT",
      "SCREENTEST,MALE", "SCREENTEST,FEMALE", "MAXTEST0,PATIENT",
      "MAXTEST1,PATIENT", "MAXTEST2,PATIENT", "MAXTEST3,PATIENT",
      "MAXTEST4,PATIENT", "CROSSREF,TEST", "NEWNAME,TEST", 
      "DBTEST0,PATIENT", "DBTEST1,PATIENT", "DBTEST2,PATIENT",
      "UPDATED,PATIENT"
    ]
    
    test_names.each do |name|
      begin
        # Find and delete any test records
        find_result = @filebot.find_entries(@test_file_number, name, ".01")
        if find_result[:success] && find_result[:count] > 0
          find_result[:results].each do |result|
            @filebot.unlock_entry(@test_file_number, result[:ien]) rescue nil
            @filebot.delete_entry(@test_file_number, result[:ien]) rescue nil
          end
        end
      rescue => e
        # Ignore cleanup errors
        puts "Test cleanup error: #{e.message}"
      end
    end
  end
end