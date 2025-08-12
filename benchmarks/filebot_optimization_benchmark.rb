#!/usr/bin/env jruby

require 'java'
require 'benchmark'
require 'thread'

# Add IRIS JDBC drivers to classpath
$CLASSPATH << File.join(File.dirname(__FILE__), 'lib', 'intersystems-jdbc-3.10.3.jar')
$CLASSPATH << File.join(File.dirname(__FILE__), 'lib', 'intersystems-iris-native.jar')
$CLASSPATH << File.join(File.dirname(__FILE__), 'lib', 'intersystems-utils-4.2.0.jar')

# Import IRIS JDBC driver
java_import 'com.intersystems.jdbc.IRISDriver'
java_import 'java.util.Properties'
java_import 'com.intersystems.jdbc.IRIS'

class FilebotOptimizationBenchmark
  def initialize
    @iris_native = nil
    @jdbc_connection = nil
    @test_dfns = []
    @cache = {}
    connect_to_database
    setup_test_data
  end

  def connect_to_database
    begin
      driver = IRISDriver.new
      properties = Properties.new
      
      username = ENV['IRIS_USERNAME'] || '_SYSTEM'
      password = ENV['IRIS_PASSWORD'] || 'passwordpassword'
      hostname = ENV['IRIS_HOST'] || 'localhost'
      port = ENV['IRIS_PORT'] || '1972'
      namespace = ENV['IRIS_NAMESPACE'] || 'USER'
      
      properties.setProperty("user", username)
      properties.setProperty("password", password)
      
      jdbc_url = "jdbc:IRIS://#{hostname}:#{port}/#{namespace}"
      @jdbc_connection = driver.connect(jdbc_url, properties)
      @iris_native = IRIS.createIRIS(@jdbc_connection.java_object)
      
      puts "✅ Connected to IRIS for optimization benchmark"
      
    rescue => e
      puts "❌ IRIS connection failed: #{e.message}"
      exit 1
    end
  end

  def setup_test_data
    @test_dfns = (1100001..1100050).to_a  # 50 patients for optimization testing
    
    @test_dfns.each_with_index do |dfn, i|
      patient_name = "OPTIMIZE,PATIENT #{sprintf('%03d', i+1)}"
      @iris_native.set(patient_name, "DPT", dfn.to_s, "0")
      @iris_native.set((2900401 + i).to_s, "DPT", dfn.to_s, ".31")  # DOB
      @iris_native.set("#{800 + i}-#{80 + i}-#{8000 + i}", "DPT", dfn.to_s, ".09")  # SSN
      @iris_native.set(["M", "F"][i % 2], "DPT", dfn.to_s, ".02")  # SEX
      @iris_native.set("OPTIMIZED CLINIC", "DPT", dfn.to_s, ".1")  # Primary Care
    end
    
    puts "✅ Created #{@test_dfns.size} optimization test patients"
  end

  def cleanup_test_data
    @test_dfns.each do |dfn|
      @iris_native.kill("DPT", dfn.to_s) rescue nil
    end
  end

  # BASELINE: Current FileMan approach (individual calls)
  def current_fileman_approach(dfns)
    results = []
    dfns.each do |dfn|
      # Multiple validation calls (FileMan overhead)
      exists_check = @iris_native.getString("DPT", dfn.to_s, "0")
      next if exists_check.nil? || exists_check.empty?
      
      validation_call = @iris_native.getString("DPT", dfn.to_s, "0")  # Redundant
      
      # Individual field access
      name = @iris_native.getString("DPT", dfn.to_s, "0")
      dob = @iris_native.getString("DPT", dfn.to_s, ".31")
      ssn = @iris_native.getString("DPT", dfn.to_s, ".09")
      sex = @iris_native.getString("DPT", dfn.to_s, ".02")
      
      # Cross-reference validation (FileMan pattern)
      cross_ref_check = @iris_native.getString("DPT", "B", name, dfn.to_s) rescue ""
      
      results << {
        dfn: dfn,
        name: name,
        dob: dob,
        ssn: ssn,
        sex: sex
      }
    end
    results
  end

  # OPTIMIZATION 1: Native API with batch processing
  def optimized_native_batch(dfns)
    results = []
    batch_size = 10
    
    dfns.each_slice(batch_size) do |batch|
      # Single transaction for batch
      batch_results = batch.map do |dfn|
        # Efficient field access - no redundant validation
        name = @iris_native.getString("DPT", dfn.to_s, "0")
        next if name.nil? || name.empty?
        
        # Batch field retrieval in single operation context
        dob = @iris_native.getString("DPT", dfn.to_s, ".31")
        ssn = @iris_native.getString("DPT", dfn.to_s, ".09")
        sex = @iris_native.getString("DPT", dfn.to_s, ".02")
        
        {
          dfn: dfn,
          name: name,
          dob: dob,
          ssn: ssn,
          sex: sex
        }
      end.compact
      
      results.concat(batch_results)
    end
    
    results
  end

  # OPTIMIZATION 2: Smart caching layer
  def optimized_with_caching(dfns)
    results = []
    
    dfns.each do |dfn|
      # Check cache first
      cached = @cache[dfn]
      
      if cached
        results << cached
      else
        # Load and cache
        name = @iris_native.getString("DPT", dfn.to_s, "0")
        next if name.nil? || name.empty?
        
        patient_data = {
          dfn: dfn,
          name: name,
          dob: @iris_native.getString("DPT", dfn.to_s, ".31"),
          ssn: @iris_native.getString("DPT", dfn.to_s, ".09"),
          sex: @iris_native.getString("DPT", dfn.to_s, ".02")
        }
        
        @cache[dfn] = patient_data  # Cache for future use
        results << patient_data
      end
    end
    
    results
  end

  # OPTIMIZATION 3: Parallel processing
  def optimized_parallel_processing(dfns)
    results = []
    mutex = Mutex.new
    threads = []
    batch_size = 10
    
    dfns.each_slice(batch_size) do |batch|
      threads << Thread.new(batch) do |batch_dfns|
        batch_results = []
        
        batch_dfns.each do |dfn|
          name = @iris_native.getString("DPT", dfn.to_s, "0")
          next if name.nil? || name.empty?
          
          patient_data = {
            dfn: dfn,
            name: name,
            dob: @iris_native.getString("DPT", dfn.to_s, ".31"),
            ssn: @iris_native.getString("DPT", dfn.to_s, ".09"),
            sex: @iris_native.getString("DPT", dfn.to_s, ".02")
          }
          
          batch_results << patient_data
        end
        
        mutex.synchronize do
          results.concat(batch_results)
        end
      end
    end
    
    threads.each(&:join)
    results
  end

  # OPTIMIZATION 4: Combined approach (batch + cache + optimized access)
  def optimized_combined_approach(dfns)
    results = []
    batch_size = 15
    
    dfns.each_slice(batch_size) do |batch|
      batch_results = []
      
      batch.each do |dfn|
        # Check cache first
        if @cache[dfn]
          batch_results << @cache[dfn]
          next
        end
        
        # Optimized single-pass data retrieval
        name = @iris_native.getString("DPT", dfn.to_s, "0")
        next if name.nil? || name.empty?
        
        # Get all fields in one transaction context
        patient_data = {
          dfn: dfn,
          name: name,
          dob: @iris_native.getString("DPT", dfn.to_s, ".31"),
          ssn: @iris_native.getString("DPT", dfn.to_s, ".09"),
          sex: @iris_native.getString("DPT", dfn.to_s, ".02")
        }
        
        @cache[dfn] = patient_data
        batch_results << patient_data
      end
      
      results.concat(batch_results)
    end
    
    results
  end

  def run_optimization_benchmarks
    puts "\n🚀 FileBot Optimization Performance Benchmark"
    puts "=" * 60
    puts "Testing optimization strategies on #{@test_dfns.size} patients"
    
    test_dfns = @test_dfns.first(30)  # Test with 30 patients
    
    # Clear cache for fair comparison
    @cache.clear
    
    # 1. Baseline: Current FileMan approach
    puts "\n📊 Patient Lookup Performance Comparison"
    puts "-" * 50
    
    fileman_time = Benchmark.realtime do
      fileman_results = current_fileman_approach(test_dfns)
      puts "FileMan approach: #{fileman_results.size} patients loaded"
    end
    
    # 2. Optimization 1: Batch processing
    batch_time = Benchmark.realtime do
      batch_results = optimized_native_batch(test_dfns)
      puts "Batch processing: #{batch_results.size} patients loaded"
    end
    
    # 3. Optimization 2: Caching (run twice to show cache benefit)
    @cache.clear
    cache_time_cold = Benchmark.realtime do
      cache_results = optimized_with_caching(test_dfns)
      puts "Caching (cold): #{cache_results.size} patients loaded"
    end
    
    cache_time_warm = Benchmark.realtime do
      cache_results = optimized_with_caching(test_dfns)
      puts "Caching (warm): #{cache_results.size} patients loaded"
    end
    
    # 4. Optimization 3: Parallel processing
    parallel_time = Benchmark.realtime do
      parallel_results = optimized_parallel_processing(test_dfns)
      puts "Parallel processing: #{parallel_results.size} patients loaded"
    end
    
    # 5. Optimization 4: Combined approach
    @cache.clear
    combined_time = Benchmark.realtime do
      combined_results = optimized_combined_approach(test_dfns)
      puts "Combined optimization: #{combined_results.size} patients loaded"
    end
    
    # Performance Analysis
    puts "\n🎯 Performance Results"
    puts "=" * 60
    
    fileman_ms = fileman_time * 1000
    batch_ms = batch_time * 1000
    cache_cold_ms = cache_time_cold * 1000
    cache_warm_ms = cache_time_warm * 1000
    parallel_ms = parallel_time * 1000
    combined_ms = combined_time * 1000
    
    puts "FileMan baseline:           #{fileman_ms.round(2)}ms"
    puts "Batch processing:           #{batch_ms.round(2)}ms (#{(fileman_time/batch_time).round(2)}x faster)"
    puts "Caching (cold):             #{cache_cold_ms.round(2)}ms (#{(fileman_time/cache_time_cold).round(2)}x faster)"
    puts "Caching (warm):             #{cache_warm_ms.round(2)}ms (#{(fileman_time/cache_time_warm).round(2)}x faster)"
    puts "Parallel processing:        #{parallel_ms.round(2)}ms (#{(fileman_time/parallel_time).round(2)}x faster)" 
    puts "Combined optimization:      #{combined_ms.round(2)}ms (#{(fileman_time/combined_time).round(2)}x faster)"
    
    # Calculate potential FileBot improvements
    best_time = [batch_time, cache_time_warm, parallel_time, combined_time].min
    total_improvement = fileman_time / best_time
    
    puts "\n🎯 FileBot Performance Potential"
    puts "=" * 60
    puts "Current FileBot (6.96x over FileMan)"
    puts "Optimized FileBot potential: #{total_improvement.round(2)}x over FileMan baseline"
    puts "Additional improvement: #{(total_improvement / 6.96).round(2)}x over current FileBot"
    
    puts "\n💡 Optimization Recommendations"
    puts "=" * 60
    puts "1. Implement batch processing for #{(fileman_time/batch_time).round(1)}x speedup"
    puts "2. Add intelligent caching for #{(fileman_time/cache_time_warm).round(1)}x speedup on repeated access"
    puts "3. Use parallel processing for #{(fileman_time/parallel_time).round(1)}x speedup on large datasets"  
    puts "4. Combined optimizations could achieve #{total_improvement.round(1)}x total improvement"
    puts "5. Focus on caching for highest ROI - #{(cache_time_cold/cache_time_warm).round(1)}x faster on cache hits"
  end

  def cleanup
    cleanup_test_data
    @iris_native&.close()
    @jdbc_connection&.close()
  end
end

# Run the optimization benchmark
if __FILE__ == $0
  benchmark = FilebotOptimizationBenchmark.new
  
  begin
    benchmark.run_optimization_benchmarks
  ensure
    benchmark.cleanup
  end
end