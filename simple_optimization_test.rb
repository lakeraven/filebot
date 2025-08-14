#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'

puts "🔍 Simple FileBot Global Access Performance Test"
puts "=" * 55

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
  iris_native = filebot.adapter.instance_variable_get(:@iris_native)
  
  puts "🚀 Setting up test data using working methods..."
  
  # Use direct IRIS calls to set up test data (avoid syntax errors)
  (0..20).each do |i|
    iris_native.set("Test Value #{i}", "OPTIMIZE_TEST", "KEY#{i}")
  end
  puts "   ✅ Test data created via direct IRIS calls"
  
  puts "\n🎯 PERFORMANCE ANALYSIS"
  
  # Test 1: Direct IRIS Native SDK
  direct_get = micro_benchmark("Direct iris_native.getString()", 30) do |i|
    iris_native.getString("OPTIMIZE_TEST", "KEY#{i % 10}")
  end
  
  # Test 2: FileBot wrapper
  filebot_get = micro_benchmark("FileBot get_global() wrapper", 30) do |i|
    filebot.adapter.get_global("^OPTIMIZE_TEST", "KEY#{i % 10}")
  end
  
  puts "\n📈 OVERHEAD ANALYSIS"
  
  overhead_ms = (filebot_get - direct_get).round(4)
  overhead_percent = ((overhead_ms / direct_get) * 100).round(1)
  slowdown_factor = (filebot_get / direct_get).round(2)
  
  puts "   Direct IRIS: #{direct_get}ms"
  puts "   FileBot wrapper: #{filebot_get}ms" 
  puts "   Overhead: #{overhead_ms}ms (#{overhead_percent}%)"
  puts "   Slowdown factor: #{slowdown_factor}x"
  
  # Test individual optimization components
  puts "\n🔬 COMPONENT OVERHEAD ANALYSIS"
  
  # Regex overhead
  regex_time = micro_benchmark("Regex processing (^GLOBAL -> GLOBAL)", 1000) do |i|
    "^OPTIMIZE_TEST".sub(/^\^/, '')
  end
  
  # String processing alternative
  string_time = micro_benchmark("String indexing (^GLOBAL -> GLOBAL)", 1000) do |i|
    "^OPTIMIZE_TEST".start_with?('^') ? "^OPTIMIZE_TEST"[1..-1] : "^OPTIMIZE_TEST"
  end
  
  # Argument processing
  args_time = micro_benchmark("Array operations (*subscripts)", 1000) do |i|
    subscripts = ["KEY#{i % 10}"]
    subscripts.empty? ? "empty" : "not_empty"
  end
  
  puts "   Regex overhead: #{regex_time}ms per operation"
  puts "   String indexing: #{string_time}ms per operation"  
  puts "   Array processing: #{args_time}ms per operation"
  
  # Calculate optimization potential
  regex_improvement = ((regex_time - string_time) / regex_time * 100).round(1)
  
  puts "\n🎯 OPTIMIZATION POTENTIAL"
  puts "   Regex -> String indexing: #{regex_improvement}% improvement"
  puts "   Total measured overhead: #{(regex_time + args_time).round(4)}ms"
  puts "   Actual wrapper overhead: #{overhead_ms}ms"
  puts "   Unexplained overhead: #{(overhead_ms - regex_time - args_time).round(4)}ms"
  
  # Test optimization simulation
  puts "\n🚀 OPTIMIZATION SIMULATION"
  
  optimized_get = micro_benchmark("Simulated optimized FileBot", 30) do |i|
    # Simulate what an optimized version would do:
    # 1. Fast string processing instead of regex
    clean_global = "OPTIMIZE_TEST"  # Pre-processed
    key = "KEY#{i % 10}"
    
    # 2. Direct call without extra processing
    iris_native.getString(clean_global, key)
  end
  
  improvement_ms = (filebot_get - optimized_get).round(4)
  improvement_percent = ((improvement_ms / filebot_get) * 100).round(1)
  
  puts "   Current FileBot: #{filebot_get}ms"
  puts "   Optimized simulation: #{optimized_get}ms"
  puts "   Improvement: #{improvement_ms}ms (#{improvement_percent}%)"
  
  puts "\n🏁 CONCLUSIONS"
  
  # Compare to FileMan performance from our previous benchmark
  fileman_time = 0.87  # From previous honest benchmark
  current_filebot_vs_fileman = (filebot_get / fileman_time).round(2)
  optimized_filebot_vs_fileman = (optimized_get / fileman_time).round(2)
  
  puts "   Previous FileMan performance: #{fileman_time}ms"
  puts "   Current FileBot vs FileMan: #{current_filebot_vs_fileman}x slower"
  puts "   Optimized FileBot vs FileMan: #{optimized_filebot_vs_fileman}x slower"
  
  if optimized_filebot_vs_fileman < 1.0
    puts "   🏆 Optimized FileBot would be FASTER than FileMan!"
  elsif optimized_filebot_vs_fileman < 1.2
    puts "   ⚖️  Optimized FileBot would match FileMan performance"
  else
    improvement_vs_fileman = current_filebot_vs_fileman - optimized_filebot_vs_fileman
    puts "   📊 Optimization would close the gap by #{improvement_vs_fileman.round(2)}x"
  end
  
  puts "\n📝 RECOMMENDATIONS:"
  
  if improvement_percent > 15
    puts "   ✅ HIGH IMPACT: Implement optimizations (#{improvement_percent}% improvement)"
    puts "   🎯 Priority: Replace regex with string indexing"
    puts "   🎯 Priority: Streamline argument processing"
  elsif improvement_percent > 5
    puts "   ⚡ MEDIUM IMPACT: Consider optimizations (#{improvement_percent}% improvement)"
  else
    puts "   📊 LOW IMPACT: Focus optimization efforts elsewhere (#{improvement_percent}% improvement)"
  end
  
rescue => e
  puts "❌ TEST ERROR: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace:"
  e.backtrace.first(5).each { |line| puts "  #{line}" }
end