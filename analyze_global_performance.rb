#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'

puts "🔍 FileBot Global Access Performance Analysis"
puts "=" * 50

ENV['FILEBOT_DEBUG'] = '1'  # Enable debug for detailed analysis

def micro_benchmark(description, iterations = 100)
  puts "\n🧪 #{description}"
  
  times = []
  iterations.times do |i|
    start_time = Time.now
    yield(i)
    end_time = Time.now
    times << ((end_time - start_time) * 1000).round(3)
  end
  
  avg = (times.sum / times.length).round(3)
  min_time = times.min
  max_time = times.max
  
  puts "   Average: #{avg}ms, Range: #{min_time}ms - #{max_time}ms"
  avg
end

begin
  filebot = FileBot::Engine.new(:iris)
  iris_native = filebot.adapter.instance_variable_get(:@iris_native)
  
  puts "🚀 Analyzing FileBot global access bottlenecks..."
  
  # Analyze each component of the global access
  puts "\n1️⃣  COMPONENT ANALYSIS"
  
  # Test 1: Raw IRIS Native SDK performance
  direct_get = micro_benchmark("Direct iris_native.getString()", 100) do |i|
    iris_native.getString("PERF_TEST", "KEY#{i % 10}")
  end
  
  direct_set = micro_benchmark("Direct iris_native.set()", 100) do |i|
    iris_native.set("Value #{i}", "PERF_TEST", "KEY#{i % 10}")
  end
  
  # Test 2: FileBot wrapper overhead
  filebot_get = micro_benchmark("FileBot get_global()", 100) do |i|
    filebot.adapter.get_global("^PERF_TEST", "KEY#{i % 10}")
  end
  
  filebot_set = micro_benchmark("FileBot set_global()", 100) do |i|
    filebot.adapter.set_global("^PERF_TEST", "KEY#{i % 10}", "Value #{i}")
  end
  
  puts "\n2️⃣  OVERHEAD ANALYSIS"
  
  get_overhead = ((filebot_get - direct_get) / direct_get * 100).round(1)
  set_overhead = ((filebot_set - direct_set) / direct_set * 100).round(1)
  
  puts "   GET overhead: #{get_overhead}% (#{(filebot_get/direct_get).round(2)}x slower)"
  puts "   SET overhead: #{set_overhead}% (#{(filebot_set/direct_set).round(2)}x slower)"
  
  # Test 3: Identify specific bottlenecks
  puts "\n3️⃣  BOTTLENECK IDENTIFICATION"
  
  # Test regex overhead
  regex_time = micro_benchmark("Regex processing (^GLOBAL -> GLOBAL)", 100) do |i|
    "^PERF_TEST".sub(/^\^/, '')
  end
  
  # Test argument processing overhead  
  args_time = micro_benchmark("Argument processing (*subscripts)", 100) do |i|
    subscripts = ["KEY#{i % 10}"]
    subscripts.empty? ? "empty" : "not_empty"
  end
  
  # Test error handling overhead
  begin_time = micro_benchmark("Exception handling (begin/rescue)", 100) do |i|
    begin
      result = iris_native.getString("PERF_TEST", "KEY#{i % 10}")
    rescue => e
      ""
    end
  end
  
  puts "   Regex processing: #{regex_time}ms"
  puts "   Argument processing: #{args_time}ms" 
  puts "   Exception handling: #{begin_time}ms vs #{direct_get}ms (#{((begin_time/direct_get).round(2))}x)"
  
  # Test 4: Connection check overhead
  connection_check_time = micro_benchmark("Connection check (@iris_native.nil?)", 100) do |i|
    !filebot.adapter.instance_variable_get(:@iris_native).nil?
  end
  
  puts "   Connection check: #{connection_check_time}ms"
  
  puts "\n4️⃣  POTENTIAL OPTIMIZATIONS"
  
  total_overhead = regex_time + args_time + connection_check_time
  puts "   Measured overhead: #{total_overhead}ms"
  puts "   Actual overhead: #{(filebot_get - direct_get).round(3)}ms"
  puts "   Unaccounted overhead: #{((filebot_get - direct_get) - total_overhead).round(3)}ms"
  
  # Test optimized version inline
  puts "\n5️⃣  TESTING OPTIMIZATIONS"
  
  # Optimized get_global simulation
  optimized_get = micro_benchmark("Optimized get_global (no regex, cached checks)", 100) do |i|
    # Simulate optimized version
    key = "KEY#{i % 10}"
    iris_native.getString("PERF_TEST", key)
  end
  
  puts "   Optimization potential: #{((filebot_get - optimized_get) / filebot_get * 100).round(1)}% improvement"
  
  puts "\n6️⃣  OPTIMIZATION RECOMMENDATIONS"
  
  improvement_potential = ((filebot_get - direct_get) / filebot_get * 100).round(1)
  
  if improvement_potential > 20
    puts "   🎯 HIGH IMPACT optimizations available (#{improvement_potential}% potential improvement):"
    puts "      • Remove regex processing for common cases"
    puts "      • Cache connection status"
    puts "      • Optimize argument handling"
    puts "      • Consider removing exception handling for hot paths"
  elsif improvement_potential > 10  
    puts "   ⚡ MEDIUM IMPACT optimizations available (#{improvement_potential}% potential improvement):"
    puts "      • Optimize string processing"
    puts "      • Streamline argument validation"
  else
    puts "   ✅ Already well optimized (#{improvement_potential}% overhead is minimal)"
  end
  
  # Test batch operations potential
  puts "\n7️⃣  BATCH OPERATION ANALYSIS"
  
  single_ops = micro_benchmark("10 individual get operations", 10) do |i|
    10.times { |j| iris_native.getString("BATCH_TEST", "#{i}_#{j}") }
  end
  
  puts "   Individual ops: #{single_ops}ms for 10 operations (#{(single_ops/10).round(3)}ms each)"
  
  # Simulate what batch operations could achieve
  batch_potential = micro_benchmark("Simulated batch operation", 10) do |i|
    # Simulate getting 10 values in one call (if IRIS supported it)
    iris_native.getString("BATCH_TEST", "BATCH_#{i}")
  end
  
  puts "   Batch potential: #{batch_potential}ms for equivalent work"
  puts "   Batch improvement: #{((single_ops - batch_potential)/single_ops * 100).round(1)}% faster"
  
rescue => e
  puts "❌ ANALYSIS ERROR: #{e.message}"
  puts "Backtrace:"
  e.backtrace.first(5).each { |line| puts "  #{line}" }
end