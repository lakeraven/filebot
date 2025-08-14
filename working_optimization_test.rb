#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'
load 'optimized_global_methods.rb'  # Load our optimizations

puts "🔍 FileBot Optimization Performance Test"
puts "=" * 50

ENV['FILEBOT_DEBUG'] = '0'  # Clean benchmarking

def micro_benchmark(description, iterations = 30)
  puts "\n📊 #{description}"
  
  times = []
  iterations.times do |i|
    start_time = Time.now
    result = yield(i)
    end_time = Time.now
    times << ((end_time - start_time) * 1000).round(4)
  end
  
  avg = (times.sum / times.length).round(4)
  min_time = times.min
  max_time = times.max
  
  puts "   Average: #{avg}ms, Range: #{min_time}ms - #{max_time}ms"
  avg
end

begin
  filebot = FileBot::Engine.new(:iris)
  adapter = filebot.adapter
  iris_native = adapter.instance_variable_get(:@iris_native)
  
  puts "🚀 Setting up test data using working healthcare patterns..."
  
  # Use the DPT pattern that we know works from the previous benchmark
  (0..20).each do |i|
    # Use direct IRIS calls with DPT pattern (known to work)
    test_data = "OPTIMIZATION,TEST#{i}^90000000#{i}^2850101^M"
    iris_native.set(test_data, "DPT", "9000#{i}", "0")
  end
  puts "   ✅ Test data created using DPT healthcare pattern"
  
  puts "\n🎯 BASELINE PERFORMANCE"
  
  # Test 1: Direct IRIS Native SDK
  direct_get = micro_benchmark("Direct iris_native.getString()", 30) do |i|
    iris_native.getString("DPT", "9000#{i % 10}", "0")
  end
  
  # Test 2: Current FileBot wrapper
  filebot_get = micro_benchmark("Current FileBot get_global()", 30) do |i|
    adapter.get_global("^DPT", "9000#{i % 10}", "0")
  end
  
  # Test 3: Optimized FileBot methods
  optimized_get = micro_benchmark("Optimized get_global_fast()", 30) do |i|
    adapter.get_global_fast("^DPT", "9000#{i % 10}", "0")
  end
  
  puts "\n📈 OVERHEAD ANALYSIS"
  
  overhead_current = (filebot_get - direct_get).round(4)
  overhead_optimized = (optimized_get - direct_get).round(4)
  
  puts "   Direct IRIS: #{direct_get}ms"
  puts "   FileBot current: #{filebot_get}ms (+#{overhead_current}ms overhead)"
  puts "   FileBot optimized: #{optimized_get}ms (+#{overhead_optimized}ms overhead)"
  
  improvement_ms = (filebot_get - optimized_get).round(4)
  improvement_percent = ((improvement_ms / filebot_get) * 100).round(1)
  
  puts "   Optimization improvement: #{improvement_ms}ms (#{improvement_percent}%)"
  
  puts "\n🔬 COMPONENT ANALYSIS"
  
  # Test regex vs string processing
  regex_time = micro_benchmark("Regex processing", 1000) do |i|
    "^DPT".sub(/^\^/, '')
  end
  
  string_time = micro_benchmark("String indexing", 1000) do |i|
    "^DPT".start_with?('^') ? "^DPT"[1..-1] : "^DPT"
  end
  
  regex_improvement = ((regex_time - string_time) / regex_time * 100).round(1)
  puts "   Regex -> String improvement: #{regex_improvement}%"
  
  puts "\n🏆 COMPETITIVE ANALYSIS"
  
  # Compare to FileMan from previous benchmark
  fileman_time = 0.87  # From our honest benchmark
  
  current_vs_fileman = (filebot_get / fileman_time).round(2)
  optimized_vs_fileman = (optimized_get / fileman_time).round(2)
  
  puts "   FileMan baseline: #{fileman_time}ms"
  puts "   Current FileBot: #{current_vs_fileman}x slower than FileMan"
  puts "   Optimized FileBot: #{optimized_vs_fileman}x slower than FileMan"
  
  gap_closed = (current_vs_fileman - optimized_vs_fileman).round(2)
  puts "   Gap closed: #{gap_closed}x improvement vs FileMan"
  
  puts "\n🎯 BATCH OPERATIONS TEST"
  
  # Test batch operations with real data
  test_keys = (0..9).map { |i| "9000#{i}" }
  
  individual_time = micro_benchmark("10 individual GET calls", 10) do |i|
    test_keys.each { |key| adapter.get_global("^DPT", key, "0") }
  end
  
  batch_time = micro_benchmark("Batch GET operation", 10) do |i|
    # Simulate batch call using our optimized method
    results = {}
    test_keys.each { |key| results[key] = adapter.get_global_fast("^DPT", key, "0") }
    results
  end
  
  batch_improvement = ((individual_time - batch_time) / individual_time * 100).round(1)
  puts "   Individual: #{individual_time}ms for 10 operations"
  puts "   Batch: #{batch_time}ms for 10 operations"
  puts "   Batch improvement: #{batch_improvement}%"
  
  puts "\n🏁 FINAL ASSESSMENT"
  
  if improvement_percent > 15
    puts "   🚀 HIGH IMPACT: #{improvement_percent}% improvement available"
    puts "   ✅ RECOMMENDATION: Deploy optimizations immediately"
  elsif improvement_percent > 8
    puts "   ⚡ MEDIUM IMPACT: #{improvement_percent}% improvement available"
    puts "   ✅ RECOMMENDATION: Deploy optimizations"
  elsif improvement_percent > 3
    puts "   📊 LOW IMPACT: #{improvement_percent}% improvement available"
    puts "   📊 RECOMMENDATION: Consider deployment"
  else
    puts "   ✅ MINIMAL IMPACT: #{improvement_percent}% improvement"
    puts "   📊 RECOMMENDATION: Focus efforts elsewhere"
  end
  
  if optimized_vs_fileman < 1.1
    puts "   🏆 ACHIEVEMENT: FileBot would be competitive with FileMan!"
  elsif gap_closed > 0.2
    puts "   📈 PROGRESS: Significant improvement vs FileMan (#{gap_closed}x closer)"
  end
  
rescue => e
  puts "❌ TEST ERROR: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace:"
  e.backtrace.first(8).each { |line| puts "  #{line}" }
end