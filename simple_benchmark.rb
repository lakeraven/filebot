#!/usr/bin/env jruby

# Simple FileBot Performance Benchmark
# Quick performance measurement against live IRIS
require_relative 'lib/filebot'
require 'benchmark'

puts "⚡ FileBot Simple Performance Benchmark"
puts "=" * 50

begin
  # Initialize FileBot
  filebot = FileBot.new(:iris)
  puts "✅ FileBot connected to IRIS"
  
  # Test patient creation
  test_patient = {
    dfn: '5555',
    name: 'BENCHMARK,PATIENT',
    ssn: '555-00-5555',
    dob: '1980-01-01',
    sex: 'M'
  }
  
  puts "\n📊 Running Performance Tests..."
  
  # 1. Patient Creation
  creation_time = Benchmark.realtime do
    result = filebot.create_patient(test_patient)
    puts "   Patient creation: #{result[:success] ? 'Success' : 'Failed'}"
  end
  puts "✅ Patient Creation: #{(creation_time * 1000).round(2)}ms"
  
  # 2. Patient Lookup
  lookup_times = []
  5.times do |i|
    time = Benchmark.realtime do
      patient = filebot.get_patient_demographics('5555')
      raise "Lookup failed" unless patient && patient[:name] == 'BENCHMARK,PATIENT'
    end
    lookup_times << time * 1000
  end
  avg_lookup = lookup_times.sum / lookup_times.length
  puts "✅ Patient Lookup: #{avg_lookup.round(2)}ms average (5 runs)"
  puts "   Individual times: #{lookup_times.map { |t| t.round(2) }.join('ms, ')}ms"
  
  # 3. Patient Search
  search_times = []
  3.times do |i|
    time = Benchmark.realtime do
      results = filebot.search_patients_by_name('BENCHMARK')
      puts "   Search found #{results.length} patients" if i == 0
    end
    search_times << time * 1000
  end
  avg_search = search_times.sum / search_times.length
  puts "✅ Patient Search: #{avg_search.round(2)}ms average (3 runs)"
  
  # 4. Global Operations
  global_times = []
  5.times do |i|
    time = Benchmark.realtime do
      # Test basic global operations
      filebot.adapter.set_global("^FILEBOT", "BENCH", "test_value_#{i}")
      result = filebot.adapter.get_global("^FILEBOT", "BENCH")
      raise "Global operation failed" unless result == "test_value_#{i}"
    end
    global_times << time * 1000
  end
  avg_global = global_times.sum / global_times.length
  puts "✅ Global Operations: #{avg_global.round(2)}ms average (5 runs)"
  
  # 5. Connection Efficiency Test
  connection_time = Benchmark.realtime do
    20.times do |i|
      # Rapid operations to test connection efficiency
      filebot.get_patient_demographics('5555')
      filebot.adapter.get_global("^FILEBOT", "BENCH")
    end
  end
  avg_per_op = (connection_time * 1000) / 40
  puts "✅ Connection Efficiency: #{avg_per_op.round(2)}ms per operation (40 operations)"
  
  puts "\n📈 PERFORMANCE SUMMARY"
  puts "=" * 30
  puts "Patient Creation:     #{(creation_time * 1000).round(2)}ms"
  puts "Patient Lookup:       #{avg_lookup.round(2)}ms"  
  puts "Patient Search:       #{avg_search.round(2)}ms"
  puts "Global Operations:    #{avg_global.round(2)}ms"
  puts "Connection Efficiency: #{avg_per_op.round(2)}ms per op"
  
  # Performance Grade
  critical_avg = [avg_lookup, avg_global, avg_per_op].sum / 3
  grade = case critical_avg
          when 0..50 then "A+ (Excellent)"
          when 51..150 then "A (Very Good)"
          when 151..300 then "B (Good)"
          when 301..500 then "C (Acceptable)"
          else "D (Needs Improvement)"
          end
  
  puts "\n🏆 Overall Performance Grade: #{grade}"
  puts "   Critical operations average: #{critical_avg.round(2)}ms"
  
  if critical_avg < 100
    puts "\n💡 Analysis: Excellent performance for healthcare applications"
    puts "   Ready for production environments"
  elsif critical_avg < 300
    puts "\n💡 Analysis: Good performance characteristics"
    puts "   Suitable for most healthcare workflows"
  else
    puts "\n💡 Analysis: Acceptable performance"
    puts "   Consider optimization for high-volume environments"
  end
  
  # Cleanup
  filebot.adapter.set_global("^DPT", "5555", "")
  filebot.adapter.set_global("^FILEBOT", "BENCH", "")
  puts "\n🧹 Cleanup completed"
  
rescue => e
  puts "❌ Benchmark failed: #{e.message}"
  puts "   Make sure IRIS is running and IRIS_PASSWORD is set"
end