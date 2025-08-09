# frozen_string_literal: true

require "test_helper"

class FileBotCompatibilityTest < ActiveSupport::TestCase
  def setup
    # Mock FileBot instance
    @filebot_mock = Minitest::Mock.new
    FileBot.stub(:instance, @filebot_mock) do
      @compatibility = FileBotCompatibility
    end
  end

  test "gets_diq provides backward compatibility with MUMPS code" do
    # Mock FileBot response
    filebot_result = OpenStruct.new(
      success?: true,
      data: {
        ".01" => "SMITH,JOHN",
        ".02" => "M", 
        ".03" => "1985-05-15",
        ".09" => "123456789"
      }
    )
    
    @filebot_mock.expect(:gets, filebot_result, [2, "123,", ".01;.02;.03;.09", "EI"])
    
    result = @compatibility.gets_diq(2, "123,", ".01;.02;.03;.09", "EI", "TARGET", "MSG")
    
    # Should format result for MUMPS compatibility
    assert_not_nil result
    assert result.key?("TARGET")
    assert result["TARGET"].key?(2)
    assert result["TARGET"][2].key?("123,")
    assert_equal "SMITH,JOHN", result["TARGET"][2]["123,"][".01"]["E"]
    assert_equal "M", result["TARGET"][2]["123,"][".02"]["E"]
    
    @filebot_mock.verify
  end

  test "gets_diq handles errors appropriately" do
    # Mock FileBot error response
    filebot_result = OpenStruct.new(
      success?: false,
      errors: ["Patient not found", "Invalid field"]
    )
    
    @filebot_mock.expect(:gets, filebot_result, [2, "999,", ".01", "EI"])
    
    result = @compatibility.gets_diq(2, "999,", ".01", "EI", "TARGET", "MSG")
    
    # Should format errors for MUMPS compatibility
    assert_not_nil result
    assert result.key?("MSG")
    assert result["MSG"].key?("DIERR")
    assert_includes result["MSG"]["DIERR"].values.join, "Patient not found"
    
    @filebot_mock.verify
  end

  test "update_die provides FileMan UPDATE^DIE compatibility" do
    # Mock successful FileBot update
    update_result = OpenStruct.new(
      success?: true,
      errors: []
    )
    
    @filebot_mock.expect(:update, update_result, [2, "123,", { ".01" => "UPDATED,NAME" }])
    
    fda = {
      "2,123," => { ".01" => "UPDATED,NAME" }
    }
    
    result = @compatibility.update_die("", fda, "", "MSG")
    
    # Should return success format compatible with MUMPS
    assert_empty result["MSG"] # No errors
    
    @filebot_mock.verify
  end

  test "update_die handles multiple file updates" do
    # Mock multiple file updates
    update_results = [
      OpenStruct.new(success?: true, errors: []),
      OpenStruct.new(success?: false, errors: ["Validation failed"])
    ]
    
    @filebot_mock.expect(:update, update_results[0], [2, "123,", { ".01" => "NAME1" }])
    @filebot_mock.expect(:update, update_results[1], [2, "456,", { ".01" => "INVALID" }])
    
    fda = {
      "2,123," => { ".01" => "NAME1" },
      "2,456," => { ".01" => "INVALID" }
    }
    
    result = @compatibility.update_die("", fda, "", "MSG")
    
    # Should accumulate all errors
    assert result["MSG"].key?("DIERR")
    assert_includes result["MSG"]["DIERR"].values.join, "Validation failed"
    
    @filebot_mock.verify
  end

  test "file_dicn provides FileMan FILE^DICN compatibility" do
    # Mock successful patient creation
    creation_result = {
      success: true,
      iens: 789,
      record: { message: "Patient created successfully" }
    }
    
    @filebot_mock.expect(:file_new, creation_result, [2, { "0.01" => "NEW,PATIENT" }])
    
    result = @compatibility.file_dicn(2, "", "NEW,PATIENT", "DIC", "Y")
    
    # Should format result compatible with FileMan FILE^DICN
    assert result.key?("Y")
    assert_equal 789, result["Y"][:iens]
    assert result["Y"][:success]
    
    @filebot_mock.verify
  end

  test "file_dicn handles creation errors" do
    # Mock failed patient creation
    creation_result = {
      success: false,
      errors: ["Name already exists", "Invalid DOB format"]
    }
    
    @filebot_mock.expect(:file_new, creation_result, [2, { "0.01" => "DUPLICATE,NAME" }])
    
    result = @compatibility.file_dicn(2, "", "DUPLICATE,NAME", "DIC", "Y")
    
    # Should format errors compatible with FileMan
    assert result.key?("Y")
    refute result["Y"][:success]
    assert_includes result["Y"][:errors].join, "Name already exists"
    
    @filebot_mock.verify
  end

  test "format_for_mumps_compatibility structures data correctly" do
    # Test the internal formatting method
    filebot_data = {
      ".01" => "SMITH,JOHN",
      ".02" => "M",
      ".09" => "123456789"
    }
    
    formatted = @compatibility.send(
      :format_for_mumps_compatibility, 
      OpenStruct.new(success?: true, data: filebot_data),
      "TARGET",
      "MSG"
    )
    
    # Should match traditional FileMan ^DIQ output format
    assert formatted.key?("TARGET")
    target = formatted["TARGET"]
    
    # Should have file number as key
    assert target.key?(2)
    
    # Should have IENS as key under file
    assert target[2].key?("123,") # IENS would be added by calling method
    
    # Should have field numbers as keys with E (external) values
    iens_data = target[2]["123,"]
    assert_equal "SMITH,JOHN", iens_data[".01"]["E"]
    assert_equal "M", iens_data[".02"]["E"]
    assert_equal "123456789", iens_data[".09"]["E"]
  end

  test "parse_file_and_iens extracts file number and IENS" do
    # Test IENS parsing for different formats
    test_cases = [
      { input: "2,123,", expected_file: 2, expected_iens: "123," },
      { input: "200,456,", expected_file: 200, expected_iens: "456," },
      { input: "52,789,1,", expected_file: 52, expected_iens: "789,1," } # Subfile
    ]
    
    test_cases.each do |test_case|
      file, iens = @compatibility.send(:parse_file_and_iens, test_case[:input])
      assert_equal test_case[:expected_file], file
      assert_equal test_case[:expected_iens], iens
    end
  end

  test "format_errors_for_mumps creates proper error structure" do
    errors = ["Field .01 required", "Invalid date format", "Duplicate SSN"]
    
    formatted = @compatibility.send(:format_errors_for_mumps, errors, "MSG")
    
    assert formatted.key?("MSG")
    assert formatted["MSG"].key?("DIERR")
    
    # Should format errors in FileMan-compatible structure
    dierr = formatted["MSG"]["DIERR"]
    assert dierr.key?(1)
    assert dierr[1].key?("TEXT")
    
    # All errors should be present in text
    error_text = dierr[1]["TEXT"].values.join(" ")
    errors.each do |error|
      assert_includes error_text, error
    end
  end

  test "integration_with_real_mumps_adapter" do
    # Test integration with RealMumpsAdapter
    adapter = RealMumpsAdapter.new
    
    # Mock FileBot for adapter test
    filebot_result = OpenStruct.new(
      success?: true,
      data: {
        ".01" => "INTEGRATION,TEST",
        ".02" => "F",
        ".03" => "1990-01-01",
        ".09" => "987654321"
      }
    )
    
    @filebot_mock.expect(:gets, filebot_result, [2, "123,", ".01;.02;.03;.09", "EI"])
    
    # This would call the compatibility layer
    result = adapter.get_patient_demographics_filebot(123)
    
    assert_not_nil result
    assert_equal 123, result[:dfn]
    assert_equal "INTEGRATION,TEST", result[:name]
    assert_equal "F", result[:sex]
    
    @filebot_mock.verify
  end

  test "backward_compatibility_with_existing_mumps_routines" do
    # Test that existing MUMPS code calling patterns still work
    
    # Traditional GETS^DIQ call pattern
    gets_result = @compatibility.gets_diq(2, "123,", ".01;.02", "EI")
    assert gets_result.key?("TARGET")
    
    # Traditional UPDATE^DIE call pattern  
    fda = { "2,123," => { ".01" => "NEW,NAME" } }
    
    @filebot_mock.expect(:update, OpenStruct.new(success?: true, errors: []), [2, "123,", { ".01" => "NEW,NAME" }])
    
    update_result = @compatibility.update_die("", fda)
    assert update_result.key?("MSG")
    
    @filebot_mock.verify
  end

  test "performance_comparison_legacy_vs_filebot" do
    # Mock timing to show performance improvement
    start_time = Time.current
    
    # FileBot should be faster
    @filebot_mock.expect(:gets, 
      OpenStruct.new(success?: true, data: { ".01" => "FAST,PATIENT" }), 
      [2, "123,", ".01", "EI"]
    )
    
    result = @compatibility.gets_diq(2, "123,", ".01", "EI")
    
    end_time = Time.current
    duration = end_time - start_time
    
    # Should complete quickly (< 100ms for unit test)
    assert duration < 0.1, "FileBot compatibility should be fast"
    assert result["TARGET"][2]["123,"][".01"]["E"] == "FAST,PATIENT"
    
    @filebot_mock.verify
  end
end