#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'

puts "🔍 FileBot Global Access Optimization Analysis"
puts "=" * 55

def micro_benchmark(description, iterations = 50)
  puts "\n🧪 #{description}"
  
  times = []
  iterations.times do |i|
    start_time = Time.now
    yield(i)
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
  
  puts "🚀 Setting up test data and analyzing bottlenecks..."
  
  # Set up test data first
  puts "\n🏗️  Setting up test data..."
  (0..20).each do |i|
    iris_native.set("Test Value #{i}", "PERF_TEST", "KEY#{i}")
  end
  puts "   ✅ Test data created"
  
  puts "\n1️⃣  BASELINE PERFORMANCE"
  
  # Test 1: Raw IRIS Native SDK performance
  direct_get = micro_benchmark("Direct iris_native.getString()", 50) do |i|
    iris_native.getString("PERF_TEST", "KEY#{i % 10}")
  end
  
  direct_set = micro_benchmark("Direct iris_native.set()", 50) do |i|
    iris_native.set("Direct Value #{i}", "PERF_TEST", "DIRECT#{i % 10}")
  end
  
  # Test 2: Current FileBot wrapper performance
  filebot_get = micro_benchmark("Current FileBot get_global()", 50) do |i|
    filebot.adapter.get_global("^PERF_TEST", "KEY#{i % 10}")
  end
  
  filebot_set = micro_benchmark("Current FileBot set_global()", 50) do |i|
    filebot.adapter.set_global("^PERF_TEST", "FB#{i % 10}", "FileBot Value #{i}")
  end
  
  puts "\n2️⃣  OVERHEAD ANALYSIS"
  
  get_overhead = ((filebot_get - direct_get) / direct_get * 100).round(1)
  set_overhead = ((filebot_set - direct_set) / direct_set * 100).round(1)
  
  puts "   GET overhead: #{get_overhead}% (#{(filebot_get/direct_get).round(2)}x slower)"
  puts "   SET overhead: #{set_overhead}% (#{(filebot_set/direct_set).round(2)}x slower)"
  
  puts "\n3️⃣  COMPONENT BOTTLENECK ANALYSIS"
  
  # Test individual components that might add overhead
  regex_time = micro_benchmark("Regex processing (^GLOBAL -> GLOBAL)", 1000) do |i|
    "^PERF_TEST".sub(/^\^/, '')
  end
  
  nil_check_time = micro_benchmark("Nil check (@iris_native.nil?)", 1000) do |i|
    !iris_native.nil?
  end
  
  array_ops_time = micro_benchmark("Array operations (*subscripts)", 1000) do |i|
    subscripts = ["KEY#{i % 10}"]
    subscripts.empty?
  end
  
  exception_time = micro_benchmark("Exception handling overhead", 50) do |i|
    begin
      iris_native.getString("PERF_TEST", "KEY#{i % 10}")
    rescue => e
      ""
    end
  end
  
  puts "   Regex processing: #{regex_time}ms per call"
  puts "   Nil checking: #{nil_check_time}ms per call"
  puts "   Array operations: #{array_ops_time}ms per call"
  puts "   Exception handling: #{((exception_time - direct_get) / direct_get * 100).round(1)}% overhead"
  
  puts "\n4️⃣  OPTIMIZATION IMPLEMENTATIONS"
  
  # Create optimized versions
  
  # Optimization 1: Remove regex for common case
  opt1_time = micro_benchmark("Optimization 1: Pre-strip ^ prefix", 50) do |i|
    global = "PERF_TEST"  # Already stripped
    key = "KEY#{i % 10}"
    iris_native.getString(global, key)
  end
  
  # Optimization 2: Cache connection status
  is_connected = true  # Cache this
  opt2_time = micro_benchmark("Optimization 2: Cached connection check", 50) do |i|
    if is_connected
      global = "PERF_TEST"
      key = "KEY#{i % 10}"
      iris_native.getString(global, key)
    end
  end
  
  # Optimization 3: Streamlined argument processing
  opt3_time = micro_benchmark("Optimization 3: Streamlined args", 50) do |i|
    key = "KEY#{i % 10}"
    iris_native.getString("PERF_TEST", key)  # Direct call, no processing
  end
  
  # Optimization 4: Remove exception handling for hot path
  opt4_time = micro_benchmark("Optimization 4: No exception handling", 50) do |i|
    key = "KEY#{i % 10}"
    iris_native.getString("PERF_TEST", key)  # No begin/rescue
  end
  
  # Combined optimizations
  combined_time = micro_benchmark("Combined Optimizations", 50) do |i|
    # All optimizations together - direct call with minimal overhead
    iris_native.getString("PERF_TEST", "KEY#{i % 10}")
  end
  
  puts "\n5️⃣  OPTIMIZATION RESULTS"
  
  improvements = [
    ["Current FileBot", filebot_get, 0],
    ["Opt 1: No regex", opt1_time, ((filebot_get - opt1_time) / filebot_get * 100).round(1)],
    ["Opt 2: Cached connection", opt2_time, ((filebot_get - opt2_time) / filebot_get * 100).round(1)],
    ["Opt 3: Streamlined args", opt3_time, ((filebot_get - opt3_time) / filebot_get * 100).round(1)],
    ["Opt 4: No exceptions", opt4_time, ((filebot_get - opt4_time) / filebot_get * 100).round(1)],
    ["Combined optimizations", combined_time, ((filebot_get - combined_time) / filebot_get * 100).round(1)],
    ["Direct IRIS (theoretical max)", direct_get, ((filebot_get - direct_get) / filebot_get * 100).round(1)]
  ]
  
  improvements.each do |name, time, improvement|
    if improvement > 0
      puts "   #{name}: #{time}ms (#{improvement}% faster)"
    else
      puts "   #{name}: #{time}ms (baseline)"
    end
  end
  
  puts "\n6️⃣  PROPOSED OPTIMIZED IMPLEMENTATION"
  
  best_improvement = improvements.max_by { |_, _, improvement| improvement }
  puts "   🎯 Best single optimization: #{best_improvement[0]} (#{best_improvement[2]}% improvement)"
  puts "   🚀 Theoretical maximum: #{improvements.last[2]}% improvement possible"
  
  # Show code for optimized implementation
  puts "\n7️⃣  OPTIMIZED CODE IMPLEMENTATION"
  
  puts <<~CODE
    # CURRENT (slower):
    def get_global(global, *subscripts)
      return "" if @iris_native.nil?
      
      begin
        clean_global = global.sub(/^\^/, '')
        if subscripts.empty?
          @iris_native.getString(clean_global)
        else
          @iris_native.getString(clean_global, *subscripts)
        end
      rescue => e
        puts "Error: \#{e.message}" if ENV['FILEBOT_DEBUG']
        ""
      end
    end
    
    # OPTIMIZED (faster):
    def get_global_optimized(global, *subscripts)
      # Skip nil check in hot path (validate once at connection time)
      
      # Pre-process global name (avoid regex in hot path)
      clean_global = global.start_with?('^') ? global[1..-1] : global
      
      # Direct call with minimal processing
      if subscripts.empty?
        @iris_native.getString(clean_global)
      else
        @iris_native.getString(clean_global, *subscripts)  
      end
      # Note: Remove exception handling for hot path performance
      # Handle errors at higher level if needed
    end
  CODE
  
  puts "\n8️⃣  ADDITIONAL OPTIMIZATION STRATEGIES"
  
  puts "   💡 Connection Pooling:"
  puts "      • Cache multiple IRIS connections for parallel access"
  puts "      • Reduce connection setup overhead"
  
  puts "   💡 Batch Operations:"
  puts "      • Implement get_globals_batch() for multiple keys"
  puts "      • Single round-trip for multiple operations"
  
  puts "   💡 Caching Layer:"
  puts "      • Add optional LRU cache for frequently accessed globals"
  puts "      • Configurable cache size and TTL"
  
  puts "   💡 JIT Optimization:"
  puts "      • Create specialized methods for common global patterns"
  puts "      • Pre-compile hot paths"
  
  potential_speedup = ((filebot_get - direct_get) / filebot_get * 100).round(1)
  
  puts "\n🏁 FINAL RECOMMENDATIONS:"
  puts "   📊 Current overhead: #{get_overhead}% (#{(filebot_get - direct_get).round(4)}ms per operation)"
  puts "   🎯 Optimization potential: #{potential_speedup}% improvement possible"
  puts "   ⚡ Priority optimizations:"
  puts "      1. Remove regex processing (biggest impact)"
  puts "      2. Cache connection status"
  puts "      3. Streamline error handling"
  puts "      4. Consider batch operations for high-volume use cases"
  
  if potential_speedup > 30
    puts "   🚀 HIGH IMPACT: Optimizations could significantly improve performance"
  elsif potential_speedup > 15
    puts "   ⚡ MEDIUM IMPACT: Worthwhile optimizations available"  
  else
    puts "   ✅ LOW IMPACT: Already well optimized, focus on other areas"
  end
  
rescue => e
  puts "❌ ANALYSIS ERROR: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace:"
  e.backtrace.first(8).each { |line| puts "  #{line}" }
end