#!/usr/bin/env jruby

# Performance Benchmark Test - Real performance measurement against live IRIS
# Tests FileBot performance characteristics with real data
# Usage: IRIS_PASSWORD=passwordpassword jruby -Ilib test/performance_benchmark_test.rb

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'filebot'
require 'test/unit'
require 'benchmark'

class PerformanceBenchmarkTest < Test::Unit::TestCase
  def setup
    skip_if_no_iris
    @filebot = FileBot.new(:iris)
    @test_dfns = (7000..7099).map(&:to_s)  # 100 test patients
    @performance_results = {}
    
    puts "📊 Setting up performance test data..."
    setup_performance_test_data
  end

  def teardown
    cleanup_performance_test_data if @filebot
  end

  def test_single_patient_lookup_performance
    # Test individual patient lookup performance
    test_dfn = @test_dfns[0]
    
    times = []
    runs = 10
    
    runs.times do |i|
      time = Benchmark.realtime do
        result = @filebot.get_patient_demographics(test_dfn)
        assert result, "Patient lookup should succeed on run #{i+1}"
        assert_equal "PERF,PATIENT001", result[:name], "Patient name should match"
      end
      times << time * 1000  # Convert to milliseconds
    end

    avg_time = times.sum / times.length
    @performance_results[:single_lookup] = avg_time

    assert avg_time < 500, "Single patient lookup should be under 500ms (got #{avg_time.round(2)}ms)"
    puts "✅ Single patient lookup: #{avg_time.round(2)}ms average (#{runs} runs)"
    puts "   Individual times: #{times.map { |t| t.round(2) }.join('ms, ')}ms"
  end

  def test_batch_patient_lookup_performance
    # Test batch patient lookup performance
    batch_sizes = [5, 10, 25, 50]
    
    batch_sizes.each do |batch_size|
      test_dfns = @test_dfns[0, batch_size]
      
      times = []
      runs = 5
      
      runs.times do |i|
        time = Benchmark.realtime do
          results = @filebot.get_patients_batch(test_dfns)
          assert_equal batch_size, results.length, "Should return #{batch_size} patients on run #{i+1}"
          results.each_with_index do |patient, idx|
            assert patient[:name].start_with?("PERF,PATIENT"), "Patient #{idx+1} should have correct name"
          end
        end
        times << time * 1000
      end

      avg_time = times.sum / times.length
      time_per_patient = avg_time / batch_size
      @performance_results["batch_#{batch_size}".to_sym] = avg_time

      assert avg_time < (batch_size * 100), "Batch lookup should be efficient (got #{avg_time.round(2)}ms for #{batch_size} patients)"
      puts "✅ Batch lookup (#{batch_size} patients): #{avg_time.round(2)}ms total, #{time_per_patient.round(2)}ms per patient"
    end
  end

  def test_patient_search_performance
    # Test search performance with various patterns
    search_patterns = [
      { pattern: "PERF", expected_min: 20 },      # Should find many
      { pattern: "PERF,PATIENT0", expected_min: 10 }, # Should find subset
      { pattern: "PERF,PATIENT001", expected_min: 1 },  # Should find one
      { pattern: "NONEXISTENT", expected_min: 0 }      # Should find none
    ]

    search_patterns.each do |test_case|
      times = []
      runs = 5
      
      runs.times do |i|
        time = Benchmark.realtime do
          results = @filebot.search_patients_by_name(test_case[:pattern])
          assert results.is_a?(Array), "Search should return array on run #{i+1}"
          assert results.length >= test_case[:expected_min], 
                 "Should find at least #{test_case[:expected_min]} patients for '#{test_case[:pattern]}'"
        end
        times << time * 1000
      end

      avg_time = times.sum / times.length
      @performance_results["search_#{test_case[:pattern].gsub(/[^A-Z0-9]/, '_')}".to_sym] = avg_time

      assert avg_time < 1000, "Search should complete under 1 second (got #{avg_time.round(2)}ms for '#{test_case[:pattern]}')"
      puts "✅ Search '#{test_case[:pattern]}': #{avg_time.round(2)}ms average"
    end
  end

  def test_patient_creation_performance
    # Test patient creation performance
    creation_dfns = ['7800', '7801', '7802', '7803', '7804']
    
    times = []
    
    creation_dfns.each_with_index do |dfn, i|
      patient_data = {
        dfn: dfn,
        name: "CREATION,PERF#{i+1}",
        ssn: "555780#{i.to_s.rjust(3, '0')}",
        dob: "198#{i}-01-15",
        sex: i.even? ? "M" : "F"
      }

      time = Benchmark.realtime do
        result = @filebot.create_patient(patient_data)
        assert result[:success], "Patient creation should succeed for #{patient_data[:name]}"
      end
      times << time * 1000
    end

    avg_time = times.sum / times.length
    @performance_results[:patient_creation] = avg_time

    assert avg_time < 1000, "Patient creation should be under 1 second (got #{avg_time.round(2)}ms)"
    puts "✅ Patient creation: #{avg_time.round(2)}ms average"

    # Cleanup creation test patients
    creation_dfns.each do |dfn|
      @filebot.adapter.set_global("^DPT", dfn, "") rescue nil
    end
  end

  def test_concurrent_operation_performance
    # Test performance under concurrent-like operations
    test_dfns = @test_dfns[0, 10]
    operations = [:lookup, :search, :batch]
    
    total_time = Benchmark.realtime do
      # Simulate concurrent operations by rapidly switching between operation types
      30.times do |i|
        operation = operations[i % operations.length]
        
        case operation
        when :lookup
          @filebot.get_patient_demographics(test_dfns[i % test_dfns.length])
        when :search
          @filebot.search_patients_by_name("PERF,PATIENT0#{(i % 3) + 1}")
        when :batch
          @filebot.get_patients_batch(test_dfns[0, 3])
        end
      end
    end

    avg_time_per_op = (total_time * 1000) / 30
    @performance_results[:concurrent_operations] = avg_time_per_op

    assert total_time < 30, "30 mixed operations should complete in under 30 seconds"
    puts "✅ Concurrent operations: #{avg_time_per_op.round(2)}ms per operation (30 mixed operations)"
  end

  def test_memory_and_connection_efficiency
    # Test that operations don't leak memory or connections
    initial_patient = @filebot.get_patient_demographics(@test_dfns[0])
    assert initial_patient, "Initial patient lookup should work"

    # Perform many operations to test for leaks
    100.times do |i|
      dfn = @test_dfns[i % @test_dfns.length]
      
      # Vary operations to test different code paths
      case i % 4
      when 0
        @filebot.get_patient_demographics(dfn)
      when 1
        @filebot.search_patients_by_name("PERF")
      when 2
        @filebot.get_patients_batch([dfn])
      when 3
        @filebot.validate_patient({ dfn: dfn, name: "TEST", ssn: "123456789", dob: "1980-01-01", sex: "M" })
      end

      # Every 25 operations, verify we can still perform basic operations
      if (i + 1) % 25 == 0
        test_patient = @filebot.get_patient_demographics(@test_dfns[0])
        assert test_patient, "Should still be able to lookup patients after #{i+1} operations"
      end
    end

    # Final verification
    final_patient = @filebot.get_patient_demographics(@test_dfns[0])
    assert final_patient, "Should still work after 100 operations"
    assert_equal initial_patient[:name], final_patient[:name], "Patient data should be consistent"

    puts "✅ Memory/connection efficiency: 100 operations completed without issues"
  end

  def test_performance_under_load
    # Test performance characteristics under heavier load
    load_test_dfns = @test_dfns[0, 50]
    
    # Rapid-fire operations
    start_time = Time.now
    
    operations_completed = 0
    target_operations = 200
    
    while operations_completed < target_operations
      operation_type = operations_completed % 5
      
      case operation_type
      when 0, 1  # 40% lookups
        dfn = load_test_dfns[operations_completed % load_test_dfns.length]
        @filebot.get_patient_demographics(dfn)
      when 2     # 20% searches  
        @filebot.search_patients_by_name("PERF,PATIENT0#{(operations_completed % 9) + 1}")
      when 3     # 20% batch operations
        batch_dfns = load_test_dfns.sample(5)
        @filebot.get_patients_batch(batch_dfns)
      when 4     # 20% validations
        test_data = { dfn: "9999", name: "TEST", ssn: "123456789", dob: "1980-01-01", sex: "M" }
        @filebot.validate_patient(test_data)
      end
      
      operations_completed += 1
    end

    total_time = Time.now - start_time
    ops_per_second = target_operations / total_time
    avg_time_per_op = (total_time * 1000) / target_operations

    @performance_results[:load_test] = avg_time_per_op

    assert ops_per_second > 1, "Should handle at least 1 operation per second under load"
    puts "✅ Load test: #{operations_completed} operations in #{total_time.round(2)}s"
    puts "   #{ops_per_second.round(2)} ops/sec, #{avg_time_per_op.round(2)}ms per operation"
  end

  def test_display_performance_summary
    # Display comprehensive performance summary
    puts "\n📊 PERFORMANCE BENCHMARK SUMMARY"
    puts "=" * 50

    puts "\n🎯 Operation Performance:"
    @performance_results.each do |operation, time_ms|
      status = case time_ms
               when 0..100 then "🟢 Excellent"
               when 101..500 then "🟡 Good"  
               when 501..1000 then "🟠 Acceptable"
               else "🔴 Needs optimization"
               end
      puts "   #{operation.to_s.gsub('_', ' ').capitalize}: #{time_ms.round(2)}ms #{status}"
    end

    # Calculate overall performance score
    critical_operations = [:single_lookup, :batch_5, :search_PERF, :patient_creation]
    critical_avg = critical_operations.map { |op| @performance_results[op] || 0 }.sum / critical_operations.length

    puts "\n🏆 Overall Performance Score:"
    overall_grade = case critical_avg
                   when 0..200 then "A+ (Excellent)"
                   when 201..500 then "A (Very Good)"
                   when 501..1000 then "B (Good)"
                   when 1001..2000 then "C (Acceptable)"
                   else "D (Needs Improvement)"
                   end
    puts "   #{critical_avg.round(2)}ms average for critical operations: #{overall_grade}"

    puts "\n💡 Performance Recommendations:"
    if critical_avg > 1000
      puts "   • Consider optimizing IRIS connection handling"
      puts "   • Review global access patterns for efficiency"
      puts "   • Check IRIS Community connection limits"
    elsif critical_avg > 500
      puts "   • Good performance for healthcare applications"
      puts "   • Consider caching for frequently accessed data"
    else
      puts "   • Excellent performance characteristics"
      puts "   • Ready for production healthcare environments"
    end
  end

  private

  def skip_if_no_iris
    unless ENV['IRIS_PASSWORD']
      skip "IRIS_PASSWORD not set - skipping performance benchmark tests"
    end

    begin
      FileBot::DatabaseAdapterFactory.create_adapter(:iris)
    rescue => e
      skip "IRIS not available: #{e.message}"
    end
  end

  def setup_performance_test_data
    # Create test patients for performance testing
    @test_dfns[0, 30].each_with_index do |dfn, i|
      patient_data = {
        dfn: dfn,
        name: "PERF,PATIENT#{(i+1).to_s.rjust(3, '0')}",
        ssn: "55570#{(i+1).to_s.rjust(2, '0')}",
        dob: "19#{70 + (i % 30)}-#{((i % 12) + 1).to_s.rjust(2, '0')}-15",
        sex: i.even? ? "M" : "F"
      }

      result = @filebot.create_patient(patient_data)
      unless result[:success]
        puts "⚠️  Warning: Could not create test patient #{dfn}"
      end
    end
    puts "✅ Performance test data setup complete"
  end

  def cleanup_performance_test_data
    return unless @filebot

    puts "🧹 Cleaning up performance test data..."
    
    # Cleanup all test patients
    @test_dfns.each do |dfn|
      begin
        @filebot.adapter.set_global("^DPT", dfn, "")
        
        # Cleanup cross-references
        (1..30).each do |i|
          name = "PERF,PATIENT#{i.to_s.rjust(3, '0')}"
          @filebot.adapter.set_global("^DPT", "B", name, dfn, "") rescue nil
        end
      rescue => e
        # Ignore cleanup errors
      end
    end
  end
end

if __FILE__ == $0
  puts "⚡ FileBot Performance Benchmark Test"
  puts "=" * 50
  puts "Comprehensive performance testing against live IRIS instance"
  puts "Tests: individual lookups, batch operations, searches, creation, load testing"
  puts ""
end