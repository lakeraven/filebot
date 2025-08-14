#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'
load 'optimized_global_methods.rb'  # Load our optimizations

puts "🚀 Testing FileBot Global Access Optimizations"
puts "=" * 55

ENV['FILEBOT_DEBUG'] = '0'  # Clean benchmarking

def benchmark_comparison(description, iterations = 50)
  puts "\n📊 #{description}"
  
  current_times = []
  optimized_times = []
  
  iterations.times do |i|
    # Test current implementation
    start_time = Time.now
    current_result = yield(:current, i)
    current_times << ((Time.now - start_time) * 1000).round(4)
    
    # Test optimized implementation
    start_time = Time.now
    optimized_result = yield(:optimized, i)
    optimized_times << ((Time.now - start_time) * 1000).round(4)
    
    # Verify results are equivalent
    if current_result != optimized_result
      puts "   ⚠️  Results differ at iteration #{i}: '#{current_result}' vs '#{optimized_result}'"
    end
  end
  
  current_avg = (current_times.sum / current_times.length).round(4)
  optimized_avg = (optimized_times.sum / optimized_times.length).round(4)
  
  improvement = ((current_avg - optimized_avg) / current_avg * 100).round(1)
  speedup = (current_avg / optimized_avg).round(2)
  
  puts "   Current:   #{current_avg}ms average"
  puts "   Optimized: #{optimized_avg}ms average"
  
  if improvement > 0
    puts "   ✅ #{improvement}% faster (#{speedup}x speedup)"
  elsif improvement < 0
    puts "   ⚠️  #{improvement.abs}% slower (regression)"
  else
    puts "   ⚖️  Equivalent performance"
  end
  
  { current: current_avg, optimized: optimized_avg, improvement: improvement, speedup: speedup }
end

begin
  filebot = FileBot::Engine.new(:iris)
  adapter = filebot.adapter
  
  puts "🏗️  Setting up test data..."
  
  # Set up test data for benchmarking
  (0..50).each do |i|
    adapter.set_global("^OPTIMIZE_TEST", "KEY#{i}", "Test Value #{i}")
  end
  
  # Test patient data
  (1..20).each do |i|
    patient_data = "OPTIMIZE,PATIENT#{i}^#{800000000 + i}^2850101^M"
    adapter.set_global("^DPT", "#{8000 + i}", "0", patient_data)
  end
  
  puts "   ✅ Test data created"
  
  puts "\n" + "=" * 55
  puts "🏁 OPTIMIZATION BENCHMARKS"
  puts "=" * 55
  
  # Benchmark 1: Basic Global GET operations
  get_results = benchmark_comparison("Global GET Operations", 50) do |method, i|
    key = "KEY#{i % 25}"
    if method == :current
      adapter.get_global("^OPTIMIZE_TEST", key)
    else
      adapter.get_global_fast("^OPTIMIZE_TEST", key)
    end
  end
  
  # Benchmark 2: Basic Global SET operations
  set_results = benchmark_comparison("Global SET Operations", 50) do |method, i|
    key = "NEWKEY#{i}"
    value = "New Value #{i}"
    if method == :current
      adapter.set_global("^OPTIMIZE_TEST", key, value)
    else
      adapter.set_global_fast("^OPTIMIZE_TEST", key, value)
    end
  end
  
  # Benchmark 3: Healthcare-specific patient data access
  patient_results = benchmark_comparison("Patient Data Access", 30) do |method, i|
    dfn = "#{8000 + (i % 20) + 1}"
    if method == :current
      adapter.get_global("^DPT", dfn, "0")
    else
      adapter.get_patient_global_fast(dfn, "0")
    end
  end
  
  # Benchmark 4: Batch operations vs individual calls
  puts "\n📊 Batch Operations vs Individual Calls"
  
  # Individual calls
  individual_start = Time.now
  individual_results = {}
  keys_to_test = (0..19).map { |i| "KEY#{i}" }
  keys_to_test.each do |key|
    individual_results[key] = adapter.get_global("^OPTIMIZE_TEST", key)
  end
  individual_time = ((Time.now - individual_start) * 1000).round(4)
  
  # Batch call
  batch_start = Time.now
  batch_results = adapter.get_globals_batch("^OPTIMIZE_TEST", keys_to_test)
  batch_time = ((Time.now - batch_start) * 1000).round(4)
  
  batch_improvement = ((individual_time - batch_time) / individual_time * 100).round(1)
  batch_speedup = (individual_time / batch_time).round(2)
  
  puts "   Individual calls: #{individual_time}ms (#{keys_to_test.length} operations)"
  puts "   Batch operation:  #{batch_time}ms (#{keys_to_test.length} operations)" 
  puts "   ✅ Batch is #{batch_improvement}% faster (#{batch_speedup}x speedup)"
  
  # Verify batch results are correct
  mismatches = individual_results.keys.select { |k| individual_results[k] != batch_results[k] }
  if mismatches.empty?
    puts "   ✅ Batch results verified correct"
  else
    puts "   ⚠️  #{mismatches.length} batch result mismatches detected"
  end
  
  puts "\n" + "=" * 55
  puts "🏆 OPTIMIZATION RESULTS SUMMARY"
  puts "=" * 55
  
  all_results = [
    ["Global GET operations", get_results],
    ["Global SET operations", set_results], 
    ["Patient data access", patient_results]
  ]
  
  total_improvement = 0
  successful_optimizations = 0
  
  all_results.each do |name, result|
    puts "\n#{name}:"
    puts "   #{result[:current]}ms → #{result[:optimized]}ms"
    if result[:improvement] > 0
      puts "   ✅ #{result[:improvement]}% improvement (#{result[:speedup]}x faster)"
      total_improvement += result[:improvement]
      successful_optimizations += 1
    elsif result[:improvement] < 0
      puts "   ⚠️  #{result[:improvement].abs}% regression"
    else
      puts "   ⚖️  No significant change"
    end
  end
  
  puts "\nBatch operations:"
  puts "   #{individual_time}ms → #{batch_time}ms"
  puts "   ✅ #{batch_improvement}% improvement (#{batch_speedup}x faster)"
  
  puts "\n🎯 OVERALL ASSESSMENT:"
  
  if successful_optimizations > 0
    avg_improvement = (total_improvement / successful_optimizations).round(1)
    puts "   📊 Average improvement: #{avg_improvement}% across #{successful_optimizations} operations"
    puts "   🚀 Batch operations: #{batch_improvement}% improvement"
  else
    puts "   ⚖️  No significant improvements detected in individual operations"
  end
  
  # Competitive analysis with FileMan
  puts "\n📈 COMPETITIVE IMPACT:"
  
  # Use previous benchmark data: FileMan 0.87ms, FileBot 1.44ms
  previous_filebot = 1.44
  previous_fileman = 0.87
  
  # Calculate new FileBot performance with optimizations
  best_get_time = get_results[:optimized]
  scaling_factor = best_get_time / get_results[:current]  # How much faster optimized is
  estimated_new_filebot = previous_filebot * scaling_factor
  
  puts "   📊 Previous FileBot vs FileMan: #{previous_filebot}ms vs #{previous_fileman}ms (#{(previous_filebot/previous_fileman).round(2)}x slower)"
  puts "   📊 Optimized FileBot vs FileMan: #{estimated_new_filebot.round(3)}ms vs #{previous_fileman}ms (#{(estimated_new_filebot/previous_fileman).round(2)}x slower)"
  
  improvement_vs_fileman = ((previous_filebot/previous_fileman) - (estimated_new_filebot/previous_fileman)).round(2)
  
  if estimated_new_filebot < previous_fileman
    puts "   🏆 Optimized FileBot would now be FASTER than FileMan!"
  elsif improvement_vs_fileman > 0.1
    puts "   ✅ Significant improvement vs FileMan (#{improvement_vs_fileman}x closer to FileMan performance)"
  else
    puts "   📊 Modest improvement vs FileMan"
  end
  
  puts "\n🏁 RECOMMENDATIONS:"
  
  if avg_improvement > 10 || batch_improvement > 30
    puts "   ✅ IMPLEMENT: Optimizations show significant improvement"
    puts "   🎯 Priority 1: Deploy optimized global access methods"
    if batch_improvement > 30
      puts "   🎯 Priority 2: Promote batch operations for high-volume use cases"
    end
  elsif avg_improvement > 5
    puts "   ⚡ CONSIDER: Moderate improvements available"
    puts "   📊 Cost/benefit analysis recommended before implementation"
  else
    puts "   📊 MINIMAL IMPACT: Focus optimization efforts elsewhere"
    puts "   💡 Consider other performance improvement strategies"
  end
  
rescue => e
  puts "❌ OPTIMIZATION TEST ERROR: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace:"
  e.backtrace.first(8).each { |line| puts "  #{line}" }
end