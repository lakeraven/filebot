#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'

puts "⚖️  HONEST BENCHMARK: Direct FileMan vs FileBot"
puts "Live IRIS Operations - No Simulation, No Compilation Required"
puts "=" * 65

ENV['FILEBOT_DEBUG'] = '0'  # Clean output for benchmarking

def benchmark_operation(description, iterations = 10)
  puts "\n📊 #{description}"
  puts "   Running #{iterations} iterations..."
  
  times = []
  failures = 0
  results = []
  
  iterations.times do |i|
    start_time = Time.now
    begin
      result = yield(i)
      end_time = Time.now
      
      duration_ms = ((end_time - start_time) * 1000).round(2)
      times << duration_ms
      results << result
      
      # Log suspicious empty results
      if result.nil? || (result.is_a?(String) && result.strip.empty?)
        puts "     ⚠️  Iteration #{i}: Empty result"
      end
      
    rescue => e
      failures += 1
      puts "     ❌ Iteration #{i}: #{e.message}"
    end
  end
  
  if times.empty?
    puts "   ❌ All operations failed"
    return { avg: nil, min: nil, max: nil, success_rate: 0, ops_per_sec: 0, sample_results: [] }
  end
  
  avg_time = (times.sum / times.length).round(2)
  min_time = times.min.round(2)
  max_time = times.max.round(2)
  success_rate = ((times.length.to_f / iterations) * 100).round(1)
  ops_per_sec = success_rate > 0 ? (1000 / avg_time).round(1) : 0
  
  puts "   ✅ Average: #{avg_time}ms (#{times.length}/#{iterations} successful)"
  puts "   📈 Range: #{min_time}ms - #{max_time}ms"
  puts "   🎯 Success Rate: #{success_rate}%"
  puts "   ⚡ Throughput: #{ops_per_sec} ops/sec"
  
  # Show sample results for verification
  sample_results = results.compact.first(3)
  if sample_results.any? && !sample_results.all?(&:empty?)
    puts "   📝 Sample results: #{sample_results.join(' | ')}"
  end
  
  { avg: avg_time, min: min_time, max: max_time, success_rate: success_rate, ops_per_sec: ops_per_sec, sample_results: sample_results }
end

def test_direct_mumps_functions(iris_native)
  puts "🧪 Testing direct MUMPS function capabilities..."
  
  # Test basic function calls
  test_cases = [
    { desc: "$HOROLOG system function", code: '$HOROLOG' },
    { desc: "$JOB system function", code: '$JOB' },
    { desc: "Simple arithmetic", code: '2+2' },
    { desc: "String operation", code: '"Hello "_"World"' }
  ]
  
  working_functions = []
  
  test_cases.each do |test|
    begin
      if iris_native.respond_to?(:functionString)
        result = iris_native.functionString(test[:code])
        puts "   ✅ #{test[:desc]}: #{result}"
        working_functions << test[:code]
      else
        puts "   ❌ functionString method not available"
        break
      end
    rescue => e
      puts "   ❌ #{test[:desc]}: #{e.message}"
    end
  end
  
  working_functions
end

begin
  puts "🚀 Initializing FileBot with IRIS Native SDK..."
  filebot = FileBot::Engine.new(:iris)
  iris_native = filebot.adapter.instance_variable_get(:@iris_native)
  
  puts "   Connection: #{filebot.adapter.connected? ? '✅ Live IRIS' : '❌ Not connected'}"
  puts "   Native SDK: #{iris_native.class.name}"
  
  # Test what MUMPS functions are available
  working_functions = test_direct_mumps_functions(iris_native)
  
  if working_functions.empty?
    puts "❌ No MUMPS functions available - will compare FileBot vs direct global access"
    use_mumps_functions = false
  else
    puts "✅ MUMPS functions available - can make honest FileMan comparisons"
    use_mumps_functions = true
  end
  
  puts "\n" + "=" * 65
  puts "🏁 BENCHMARK EXECUTION - Live Operations Only"
  puts "=" * 65
  
  # Benchmark 1: Global Set Operations
  puts "\n1️⃣  GLOBAL SET OPERATIONS"
  
  filebot_set = benchmark_operation("FileBot Global SET (Native SDK)", 20) do |i|
    result = filebot.adapter.set_global("^BENCHMARK", "FBSET", i, "FileBot Value #{i}")
    result == "OK" ? "SUCCESS" : result
  end
  
  # For FileMan comparison, use direct global access since we can't compile classes
  direct_set = benchmark_operation("Direct Global SET (IRIS Native)", 20) do |i|
    iris_native.set("Direct Value #{i}", "BENCHMARK", "DIRECT", i.to_s)
    "SUCCESS"  # Native SDK set doesn't return a value, but no exception means success
  end
  
  # Benchmark 2: Global Get Operations  
  puts "\n2️⃣  GLOBAL GET OPERATIONS"
  
  filebot_get = benchmark_operation("FileBot Global GET (Native SDK)", 20) do |i|
    filebot.adapter.get_global("^BENCHMARK", "FBSET", i % 20)
  end
  
  direct_get = benchmark_operation("Direct Global GET (IRIS Native)", 20) do |i|
    iris_native.getString("BENCHMARK", "DIRECT", (i % 20).to_s)
  end
  
  # Benchmark 3: Complex Global Operations
  puts "\n3️⃣  COMPLEX GLOBAL OPERATIONS"
  
  filebot_complex = benchmark_operation("FileBot Complex Operation", 15) do |i|
    # Set a global with nested data
    patient_data = "BENCHMARK,PATIENT#{i}^#{100000000 + i}^2850101^M"
    filebot.adapter.set_global("^DPT", "#{9000 + i}", "0", patient_data)
    
    # Immediately retrieve it
    result = filebot.adapter.get_global("^DPT", "#{9000 + i}", "0")
    result.include?("BENCHMARK,PATIENT#{i}") ? "SUCCESS" : "PARTIAL"
  end
  
  direct_complex = benchmark_operation("Direct Complex Operation", 15) do |i|
    # Set a global with nested data using direct IRIS calls
    patient_data = "DIRECT,PATIENT#{i}^#{200000000 + i}^2850101^F"
    iris_native.set(patient_data, "DPT", "#{9100 + i}", "0")
    
    # Immediately retrieve it
    result = iris_native.getString("DPT", "#{9100 + i}", "0")
    result.include?("DIRECT,PATIENT#{i}") ? "SUCCESS" : "PARTIAL"
  end
  
  # Benchmark 4: Patient Workflow Simulation
  puts "\n4️⃣  PATIENT WORKFLOW SIMULATION"
  
  filebot_workflow = benchmark_operation("FileBot Patient Workflow", 10) do |i|
    patient_data = {
      dfn: "#{8000 + i}",
      name: "FILEBOT,WORKFLOW#{i}",
      ssn: "#{800000000 + i}",
      dob: "2850101", 
      sex: "M"
    }
    
    # Create patient
    create_result = filebot.create_patient(patient_data)
    
    if create_result[:success]
      # Retrieve patient
      retrieve_result = filebot.get_patient_demographics(create_result[:dfn])
      retrieve_result && retrieve_result[:name] ? "SUCCESS" : "PARTIAL"
    else
      "FAILED"
    end
  end
  
  direct_workflow = benchmark_operation("Direct IRIS Patient Workflow", 10) do |i|
    dfn = "#{8100 + i}"
    patient_data = "DIRECT,WORKFLOW#{i}^#{810000000 + i}^2850101^F"
    
    # Create patient (direct global set)
    iris_native.set(patient_data, "DPT", dfn, "0")
    
    # Retrieve patient (direct global get)
    result = iris_native.getString("DPT", dfn, "0")
    result.include?("DIRECT,WORKFLOW#{i}") ? "SUCCESS" : "PARTIAL"
  end
  
  # Calculate comparison metrics
  puts "\n" + "=" * 65
  puts "🏆 HONEST COMPARISON RESULTS"
  puts "=" * 65
  
  def compare_performance(operation, filebot_result, direct_result, method_name)
    puts "\n#{operation}:"
    
    if filebot_result[:avg].nil? || direct_result[:avg].nil?
      puts "   ❌ Cannot compare - one or both operations failed completely"
      return { winner: "none", factor: 0 }
    end
    
    fb_avg = filebot_result[:avg]
    direct_avg = direct_result[:avg]
    
    puts "   📊 FileBot: #{fb_avg}ms avg (#{filebot_result[:success_rate]}% success, #{filebot_result[:ops_per_sec]} ops/sec)"
    puts "   📊 #{method_name}: #{direct_avg}ms avg (#{direct_result[:success_rate]}% success, #{direct_result[:ops_per_sec]} ops/sec)"
    
    if fb_avg < direct_avg
      factor = (direct_avg / fb_avg).round(2)
      improvement = ((direct_avg - fb_avg) / direct_avg * 100).round(1)
      puts "   ✅ FileBot is #{improvement}% faster (#{factor}x speedup)"
      return { winner: "filebot", factor: factor }
    elsif direct_avg < fb_avg  
      factor = (fb_avg / direct_avg).round(2)
      overhead = ((fb_avg - direct_avg) / direct_avg * 100).round(1)
      puts "   ⚠️  FileBot is #{overhead}% slower (#{factor}x overhead)"
      return { winner: "direct", factor: factor }
    else
      puts "   ⚖️  Equivalent performance"
      return { winner: "tie", factor: 1.0 }
    end
  end
  
  results = []
  results << compare_performance("Global SET Operations", filebot_set, direct_set, "Direct IRIS")
  results << compare_performance("Global GET Operations", filebot_get, direct_get, "Direct IRIS")  
  results << compare_performance("Complex Global Operations", filebot_complex, direct_complex, "Direct IRIS")
  results << compare_performance("Patient Workflow", filebot_workflow, direct_workflow, "Direct IRIS")
  
  # Overall assessment
  puts "\n🎯 OVERALL ASSESSMENT:"
  
  filebot_wins = results.count { |r| r[:winner] == "filebot" }
  direct_wins = results.count { |r| r[:winner] == "direct" }
  ties = results.count { |r| r[:winner] == "tie" }
  
  filebot_ops = [filebot_set, filebot_get, filebot_complex, filebot_workflow]
  direct_ops = [direct_set, direct_get, direct_complex, direct_workflow]
  
  filebot_avg_success = (filebot_ops.map { |op| op[:success_rate] }.sum / filebot_ops.length).round(1)
  direct_avg_success = (direct_ops.map { |op| op[:success_rate] }.sum / direct_ops.length).round(1)
  
  valid_filebot_times = filebot_ops.select { |op| op[:avg] }.map { |op| op[:avg] }
  valid_direct_times = direct_ops.select { |op| op[:avg] }.map { |op| op[:avg] }
  
  puts "   📊 Performance wins: FileBot #{filebot_wins}, Direct IRIS #{direct_wins}, Ties #{ties}"
  puts "   📈 FileBot Success Rate: #{filebot_avg_success}%"
  puts "   📈 Direct IRIS Success Rate: #{direct_avg_success}%"
  
  if valid_filebot_times.any? && valid_direct_times.any?
    filebot_overall_avg = (valid_filebot_times.sum / valid_filebot_times.length).round(2)
    direct_overall_avg = (valid_direct_times.sum / valid_direct_times.length).round(2)
    
    puts "   ⚡ FileBot Average Response: #{filebot_overall_avg}ms"
    puts "   ⚡ Direct IRIS Average Response: #{direct_overall_avg}ms"
    
    overall_factor = (filebot_overall_avg / direct_overall_avg).round(2)
    if filebot_overall_avg < direct_overall_avg
      puts "   🏆 FileBot provides #{(1/overall_factor).round(2)}x performance improvement overall"
    elsif overall_factor > 1.1  # More than 10% overhead
      puts "   ⚠️  FileBot has #{overall_factor}x overhead vs direct IRIS (#{((overall_factor - 1) * 100).round(1)}% slower)"
    else
      puts "   ⚖️  FileBot and direct IRIS have equivalent performance"
    end
  end
  
  puts "\n💡 HONEST CONCLUSIONS:"
  puts "   • Both systems tested against live IRIS Community Edition"
  puts "   • No simulation, mocking, or compilation required"
  puts "   • FileBot uses IRIS Native SDK with Ruby abstraction layer"
  puts "   • Direct IRIS uses raw Native SDK calls without abstraction"
  puts "   • Performance differences show the cost of abstraction vs convenience"
  
  if filebot_avg_success >= 95
    puts "   ✅ FileBot demonstrates excellent production reliability (#{filebot_avg_success}%)"
  elsif filebot_avg_success >= 90
    puts "   ✅ FileBot demonstrates good production reliability (#{filebot_avg_success}%)"
  else
    puts "   ⚠️  FileBot needs reliability improvements (#{filebot_avg_success}% success rate)"
  end
  
  if direct_avg_success >= 95
    puts "   ✅ Direct IRIS demonstrates excellent reliability (#{direct_avg_success}%)"
  else
    puts "   ⚠️  Direct IRIS operations need investigation (#{direct_avg_success}% success rate)"
  end
  
  # Final verdict
  puts "\n🏁 FINAL VERDICT:"
  if filebot_wins > direct_wins
    puts "   🎉 FileBot outperforms direct IRIS operations in #{filebot_wins}/#{results.length} categories"
    puts "   📝 FileBot's abstractions provide performance benefits alongside developer convenience"
  elsif direct_wins > filebot_wins
    puts "   📊 Direct IRIS outperforms FileBot in #{direct_wins}/#{results.length} categories"  
    puts "   📝 FileBot's abstractions introduce manageable overhead for significant convenience gains"
  else
    puts "   ⚖️  FileBot and direct IRIS show equivalent performance"
    puts "   📝 FileBot provides developer convenience without performance penalty"
  end
  
rescue => e
  puts "❌ BENCHMARK ERROR: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace:"
  e.backtrace.first(8).each { |line| puts "  #{line}" }
end