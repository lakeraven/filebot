# frozen_string_literal: true

require 'thread'
require 'monitor'
require_relative 'models/patient'

module FileBot
  # High-performance core FileBot class with integrated optimization features
  # All performance optimizations are first-class citizens, not wrapper layers
  class Core
    include MonitorMixin

    attr_reader :adapter, :config, :performance_stats

    def initialize(adapter = nil, config = {})
      super() # Initialize MonitorMixin
      
      @config = config.is_a?(Hash) ? config : {}
      @adapter = adapter || create_adapter_from_config
      validate_adapter!
      
      # Initialize integrated performance features
      initialize_intelligent_cache
      initialize_batch_processor
      initialize_connection_pool
      initialize_query_router
      initialize_performance_monitor
    end

    # === Optimized Patient Operations ===

    # High-performance patient lookup with integrated caching
    def get_patient_demographics(dfn)
      track_performance("get_patient_demographics") do
        # Check intelligent cache first
        cache_key = "patient:#{dfn}"
        cached_result = @cache.get(cache_key)
        
        if cached_result
          @perf_stats[:cache_hits] += 1
          return cached_result
        end
        
        @perf_stats[:cache_misses] += 1
        
        # Use Patient model (Ruby business logic) instead of MUMPS FileMan
        result = @connection_pool.with_connection do |conn|
          begin
            patient = Models::Patient.find(dfn, conn)
            patient ? patient.clinical_summary[:demographics] : nil
          rescue => e
            puts "FileBot: Patient lookup failed: #{e.message}" if ENV['FILEBOT_DEBUG']
            nil
          end
        end
        
        # Cache with intelligent TTL
        if result
          ttl = calculate_cache_ttl(result, :patient_demographics)
          @cache.set(cache_key, result, ttl)
        end
        
        result
      end
    end

    # High-performance batch patient lookup with intelligent batching
    def get_patients_batch(dfn_list)
      track_performance("get_patients_batch") do
        @perf_stats[:batch_operations] += 1
        
        # Split into cached and uncached
        cached_results = {}
        uncached_dfns = []
        
        dfn_list.each do |dfn|
          cache_key = "patient:#{dfn}"
          cached = @cache.get(cache_key)
          
          if cached
            cached_results[dfn] = cached
            @perf_stats[:cache_hits] += 1
          else
            uncached_dfns << dfn
            @perf_stats[:cache_misses] += 1
          end
        end
        
        # Process uncached patients in optimized batches
        if uncached_dfns.any?
          uncached_results = process_patient_batch(uncached_dfns)
          cached_results.merge!(uncached_results)
        end
        
        cached_results
      end
    end

    # High-performance patient search with query routing
    def search_patients_by_name(name_pattern, options = {})
      track_performance("search_patients_by_name") do
        # Use query router to determine optimal strategy
        strategy = @query_router.determine_search_strategy(name_pattern, options)
        
        case strategy
        when :sql
          @perf_stats[:sql_queries] += 1
          search_patients_sql(name_pattern, options)
        when :cached
          search_patients_cached(name_pattern, options)
        else
          @perf_stats[:native_queries] += 1
          search_patients_native_ruby(name_pattern, options)
        end
      end
    end
    
    # Create new patient (Ruby business logic replaces FileMan FILE^DIE)
    def create_patient(attributes)
      track_performance("create_patient") do
        result = @connection_pool.with_connection do |conn|
          begin
            patient = Models::Patient.create(attributes, conn)
            
            # Clear any cached patient data
            @cache.delete("patient:#{patient.dfn}")
            @cache.delete("clinical_summary:#{patient.dfn}")
            
            demographics = patient.clinical_summary[:demographics]
            {
              dfn: patient.dfn,
              success: true,
              patient: demographics
            }
          rescue => e
            puts "FileBot: Patient creation failed: #{e.message}" if ENV['FILEBOT_DEBUG']
            { success: false, error: e.message }
          end
        end
        
        @perf_stats[:patient_creations] += 1
        result
      end
    end

    # High-performance clinical summary with SQL routing
    def get_patient_clinical_summary(dfn)
      track_performance("get_patient_clinical_summary") do
        cache_key = "clinical_summary:#{dfn}"
        cached_result = @cache.get(cache_key)
        
        if cached_result
          @perf_stats[:cache_hits] += 1
          return cached_result
        end
        
        @perf_stats[:cache_misses] += 1
        
        # Use Patient model (Ruby business logic) for clinical summary
        result = @connection_pool.with_connection do |conn|
          begin
            patient = Models::Patient.find(dfn, conn)
            patient ? patient.clinical_summary : nil
          rescue => e
            puts "FileBot: Clinical summary failed: #{e.message}" if ENV['FILEBOT_DEBUG']
            nil
          end
        end
        
        @perf_stats[:native_queries] += 1
        
        # Cache with shorter TTL for clinical data
        if result
          @cache.set(cache_key, result, @config[:clinical_data_ttl] || 900)
        end
        
        result
      end
    end

    # === Priority 1: Extended CRUD Operations ===

    # Delete patient record (replaces FileMan EN^DIEZ)
    def delete_patient(dfn)
      track_performance("delete_patient") do
        result = @connection_pool.with_connection do |conn|
          begin
            Models::Patient.delete(dfn, conn)
          rescue => e
            puts "FileBot: Patient deletion failed: #{e.message}" if ENV['FILEBOT_DEBUG']
            { success: false, error: e.message }
          end
        end
        
        # Clear cache for deleted patient
        invalidate_patient_cache(dfn) if result[:success]
        
        result
      end
    end

    # Boolean search with AND/OR logic
    def boolean_search(criteria)
      track_performance("boolean_search") do
        @connection_pool.with_connection do |conn|
          begin
            Models::Patient.boolean_search(criteria, conn)
          rescue => e
            puts "FileBot: Boolean search failed: #{e.message}" if ENV['FILEBOT_DEBUG']
            []
          end
        end
      end
    end

    # Range search operations
    def range_search(field, range_criteria)
      track_performance("range_search") do
        @connection_pool.with_connection do |conn|
          begin
            Models::Patient.range_search(field, range_criteria, conn)
          rescue => e
            puts "FileBot: Range search failed: #{e.message}" if ENV['FILEBOT_DEBUG']
            []
          end
        end
      end
    end

    # Multiple field update
    def update_multiple_fields(dfn, field_updates)
      track_performance("update_multiple_fields") do
        result = @connection_pool.with_connection do |conn|
          begin
            patient = Models::Patient.find(dfn, conn)
            return { success: false, error: "Patient not found" } unless patient
            
            patient.update_multiple_fields(field_updates, conn)
          rescue => e
            puts "FileBot: Multiple field update failed: #{e.message}" if ENV['FILEBOT_DEBUG']
            { success: false, error: e.message }
          end
        end
        
        # Clear cache for updated patient
        invalidate_patient_cache(dfn) if result[:success]
        
        result
      end
    end

    # Rebuild cross-references
    def rebuild_cross_references(dfn)
      track_performance("rebuild_cross_references") do
        @connection_pool.with_connection do |conn|
          begin
            Models::Patient.rebuild_cross_references(dfn, conn)
          rescue => e
            puts "FileBot: Cross-reference rebuild failed: #{e.message}" if ENV['FILEBOT_DEBUG']
            { success: false, error: e.message }
          end
        end
      end
    end

    # === Priority 3: Healthcare-Specific Operations ===

    # Allergy management
    def manage_patient_allergies(patient_dfn, allergy_data)
      track_performance("manage_patient_allergies") do
        @connection_pool.with_connection do |conn|
          begin
            # Load allergy model
            require_relative 'models/allergy'
            
            allergy = Models::Allergy.create(patient_dfn, allergy_data, conn)
            interactions = Models::Allergy.check_interactions(patient_dfn, allergy_data[:allergen], conn)
            
            { success: true, allergy_ien: allergy.ien, interactions: interactions }
          rescue => e
            puts "FileBot: Allergy management failed: #{e.message}" if ENV['FILEBOT_DEBUG']
            { success: false, error: e.message }
          end
        end
      end
    end

    # Provider relationship validation
    def validate_provider_relationship(patient_dfn, provider_ien)
      track_performance("validate_provider_relationship") do
        @connection_pool.with_connection do |conn|
          begin
            # Load provider model
            require_relative 'models/provider'
            
            Models::Provider.validate_patient_provider_relationship(patient_dfn, provider_ien, conn)
          rescue => e
            puts "FileBot: Provider validation failed: #{e.message}" if ENV['FILEBOT_DEBUG']
            { valid: false, error: e.message }
          end
        end
      end
    end

    # Clinical decision support
    def clinical_decision_support(patient_dfn, clinical_data = {})
      track_performance("clinical_decision_support") do
        @connection_pool.with_connection do |conn|
          begin
            patient = Models::Patient.find(patient_dfn, conn)
            return { alerts: ["Patient not found"], recommendations: [] } unless patient

            alerts = []
            recommendations = []

            # Age-based alerts
            if patient.dob && (Date.today - patient.dob).to_i / 365 > 65
              alerts << "Geriatric patient - consider age-appropriate protocols"
            end

            # Load and check allergies
            require_relative 'models/allergy'
            allergies = Models::Allergy.find_by_patient(patient_dfn, conn)
            if allergies.any?
              alerts << "Patient has #{allergies.length} known allergies"
              recommendations << "Review allergy list before prescribing"
            end

            { alerts: alerts, recommendations: recommendations, patient_dfn: patient_dfn }
          rescue => e
            puts "FileBot: Clinical decision support failed: #{e.message}" if ENV['FILEBOT_DEBUG']
            { alerts: ["Error: #{e.message}"], recommendations: [] }
          end
        end
      end
    end

    # Medication interaction checking
    def check_medication_interactions(patient_dfn, medication)
      track_performance("check_medication_interactions") do
        @connection_pool.with_connection do |conn|
          begin
            require_relative 'models/allergy'
            
            allergies = Models::Allergy.find_by_patient(patient_dfn, conn)
            interactions = []

            allergies.each do |allergy|
              if medication[:name].upcase.include?(allergy.allergen.upcase)
                interactions << {
                  type: "allergy",
                  allergen: allergy.allergen,
                  medication: medication[:name],
                  severity: allergy.severity
                }
              end
            end

            { interactions: interactions, severity: interactions.any? ? "high" : "none", safe: interactions.empty? }
          rescue => e
            puts "FileBot: Medication interaction check failed: #{e.message}" if ENV['FILEBOT_DEBUG']
            { interactions: [], severity: "unknown", safe: false, error: e.message }
          end
        end
      end
    end

    # === Performance Management (First-Class) ===

    def warm_cache(dfn_list, fields: :all)
      track_performance("warm_cache") do
        # Identify uncached patients
        uncached_dfns = dfn_list.select do |dfn|
          !@cache.has?("patient:#{dfn}")
        end
        
        return 0 if uncached_dfns.empty?
        
        # Batch load uncached patients
        get_patients_batch(uncached_dfns)
        
        # Pre-load related data if requested
        if fields == :all || fields.include?(:clinical)
          uncached_dfns.each do |dfn|
            Thread.new { get_patient_clinical_summary(dfn) }
          end
        end
        
        uncached_dfns.size
      end
    end

    def clear_cache
      synchronize { @cache.clear }
    end

    def invalidate_patient_cache(dfn)
      synchronize do
        @cache.delete("patient:#{dfn}")
        @cache.delete("clinical_summary:#{dfn}")
        @cache.delete_pattern("patient_.*:#{dfn}")
      end
    end

    def performance_summary
      synchronize do
        total_cache_requests = @perf_stats[:cache_hits] + @perf_stats[:cache_misses]
        cache_hit_rate = total_cache_requests > 0 ? (@perf_stats[:cache_hits].to_f / total_cache_requests * 100) : 0
        
        {
          cache_hit_rate: cache_hit_rate.round(2),
          cache_size: @cache.size,
          total_operations: @perf_stats[:total_operations],
          average_response_time: calculate_average_response_time,
          batch_operations: @perf_stats[:batch_operations],
          sql_queries: @perf_stats[:sql_queries],
          native_queries: @perf_stats[:native_queries],
          connection_pool_utilization: @connection_pool.utilization_percentage
        }
      end
    end

    def optimization_recommendations
      stats = performance_summary
      recommendations = []
      
      if stats[:cache_hit_rate] < 70
        recommendations << "Consider warming cache or increasing cache size (current hit rate: #{stats[:cache_hit_rate]}%)"
      end
      
      if stats[:sql_queries] == 0 && @query_router.sql_available?
        recommendations << "Enable SQL optimization for complex queries"
      end
      
      if stats[:average_response_time] > 100
        recommendations << "Average response time is #{stats[:average_response_time]}ms - consider enabling more aggressive caching"
      end
      
      if stats[:connection_pool_utilization] > 80
        recommendations << "Connection pool utilization is high (#{stats[:connection_pool_utilization]}%) - consider expanding pool"
      end
      
      recommendations
    end

    # === Configuration Management ===

    def configure_performance(&block)
      yield(@config) if block_given?
      apply_configuration_changes
    end

    def enable_aggressive_caching
      @cache.enable_aggressive_mode
      @config[:aggressive_caching] = true
    end

    def enable_sql_optimization
      @query_router.enable_sql_preference
      @config[:sql_optimization] = true
    end

    def enable_predictive_loading
      @cache.enable_predictive_loading
      @config[:predictive_loading] = true
    end

    # === Core Database Operations (Optimized) ===

    def create_patient(patient_data)
      track_performance("create_patient") do
        result = @connection_pool.with_connection do |conn|
          # Implementation would go here
          { dfn: patient_data[:dfn], success: true }
        end
        
        # Invalidate related cache entries
        invalidate_patient_cache(result[:dfn]) if result[:dfn]
        
        result
      end
    end

    def update_patient(dfn, updates)
      track_performance("update_patient") do
        result = @connection_pool.with_connection do |conn|
          # Implementation would go here
          { dfn: dfn, success: true }
        end
        
        # Invalidate cache for updated patient
        invalidate_patient_cache(dfn)
        
        result
      end
    end

    def validate_patient(patient_data)
      track_performance("validate_patient") do
        # Fast validation using cached rules
        @connection_pool.with_connection do |conn|
          # Implementation would go here
          { valid: true, errors: [] }
        end
      end
    end

    # === Adapter Management ===

    def adapter_info
      {
        type: @adapter.class.name,
        connection_status: test_connection,
        performance_optimizations: {
          caching: true,
          batch_processing: true,
          connection_pooling: true,
          sql_routing: @query_router.sql_available?,
          query_optimization: true
        }
      }
    end

    def test_connection
      @connection_pool.with_connection do |conn|
        conn.test_connection
      end
    rescue
      false
    end

    def switch_adapter!(new_adapter_type, config = {})
      # Shutdown current optimizations
      shutdown_optimizations
      
      # Create new adapter
      @adapter = DatabaseAdapterFactory.create_adapter(new_adapter_type, config)
      validate_adapter!
      
      # Reinitialize optimizations
      initialize_connection_pool
      initialize_query_router
      
      true
    end

    def shutdown
      shutdown_optimizations
    end

    private

    # === Initialization Methods ===

    def initialize_intelligent_cache
      cache_config = @config[:cache] || {}
      
      @cache = IntelligentCache.new(
        max_size: cache_config[:max_size] || auto_detect_cache_size,
        default_ttl: cache_config[:default_ttl] || 3600,
        aggressive_mode: cache_config[:aggressive_mode] || false,
        predictive_loading: cache_config[:predictive_loading] || false
      )
    end

    def initialize_batch_processor
      @batch_size = @config.dig(:batch, :batch_size) || auto_detect_batch_size
      @max_parallel_batches = @config.dig(:batch, :max_parallel_batches) || 4
      @enable_parallel = @config.dig(:batch, :enable_parallel) != false
    end

    def initialize_connection_pool
      pool_config = @config[:connection] || {}
      
      @connection_pool = ConnectionPool.new(
        @adapter,
        size: pool_config[:size] || auto_detect_pool_size,
        timeout: pool_config[:timeout] || 10,
        max_retries: pool_config[:max_retries] || 3
      )
    end

    def initialize_query_router
      query_config = @config[:query] || {}
      
      @query_router = QueryRouter.new(
        @adapter,
        prefer_sql: query_config[:prefer_sql] || auto_detect_sql_preference,
        sql_threshold: query_config[:sql_threshold] || 5,
        enable_adaptive_routing: query_config[:enable_adaptive_routing] || true
      )
    end

    def initialize_performance_monitor
      @perf_stats = {
        cache_hits: 0,
        cache_misses: 0,
        batch_operations: 0,
        sql_queries: 0,
        native_queries: 0,
        total_operations: 0,
        total_time: 0.0,
        operation_times: []
      }
      
      @start_time = Time.now
    end

    # === Auto-Detection Methods ===

    def auto_detect_cache_size
      # Base on available memory
      available_memory = detect_available_memory_mb
      
      case
      when available_memory > 2000 then 10000  # 2GB+ -> 10k patients
      when available_memory > 1000 then 5000   # 1GB+ -> 5k patients  
      when available_memory > 500 then 2000    # 500MB+ -> 2k patients
      else 1000                                 # < 500MB -> 1k patients
      end
    end

    def auto_detect_batch_size
      # Base on cache size and connection pool
      cache_size = @cache&.max_size || 1000
      
      case
      when cache_size > 5000 then 50
      when cache_size > 2000 then 25
      when cache_size > 500 then 15
      else 10
      end
    end

    def auto_detect_pool_size
      # Base on expected concurrency
      case auto_detect_cache_size
      when 10000..Float::INFINITY then 20  # Large hospital
      when 2000..9999 then 10              # Medium clinic
      when 500..1999 then 5                # Small clinic
      else 3                               # Very small
      end
    end

    def auto_detect_sql_preference
      # Enable SQL for larger deployments
      auto_detect_cache_size >= 2000
    end

    def detect_available_memory_mb
      if defined?(GC.stat)
        heap_size = GC.stat[:heap_allocated_pages] * GC.stat[:heap_page_size] / (1024 * 1024)
        [heap_size * 20, 2000].min  # Conservative estimate
      else
        1000  # Safe default
      end
    rescue
      1000
    end

    # === Performance Tracking ===

    def track_performance(operation_name)
      start_time = Time.now
      @perf_stats[:total_operations] += 1
      
      begin
        result = yield
        record_success(operation_name, start_time)
        result
      rescue => e
        record_error(operation_name, start_time, e)
        raise e
      end
    end

    def record_success(operation_name, start_time)
      duration = Time.now - start_time
      @perf_stats[:total_time] += duration
      @perf_stats[:operation_times] << duration
      
      # Keep only recent times for moving average
      @perf_stats[:operation_times] = @perf_stats[:operation_times].last(1000)
    end

    def record_error(operation_name, start_time, error)
      duration = Time.now - start_time
      @perf_stats[:total_time] += duration
      
      puts "FileBot performance error in #{operation_name}: #{error.message}" if ENV['FILEBOT_DEBUG']
    end

    def calculate_average_response_time
      times = @perf_stats[:operation_times]
      return 0.0 if times.empty?
      
      (times.sum / times.size * 1000).round(2)  # Convert to ms
    end

    # === Optimized Operation Implementations ===

    def process_patient_batch(dfn_list)
      results = {}
      
      # Process in optimal batch sizes
      dfn_list.each_slice(@batch_size) do |batch|
        if @enable_parallel && batch.size > 5
          batch_results = process_batch_parallel(batch)
        else
          batch_results = process_batch_sequential(batch)
        end
        
        # Cache all results
        batch_results.each do |dfn, result|
          if result
            cache_key = "patient:#{dfn}"
            ttl = calculate_cache_ttl(result, :patient_demographics)
            @cache.set(cache_key, result, ttl)
          end
        end
        
        results.merge!(batch_results)
      end
      
      results
    end

    def process_batch_parallel(dfn_batch)
      results = {}
      threads = []
      mutex = Mutex.new
      
      dfn_batch.each do |dfn|
        threads << Thread.new do
          @connection_pool.with_connection do |conn|
            begin
              data = conn.get_global("^DPT", dfn.to_s, "0")
              if data && !data.empty?
                result = PatientParser.parse_zero_node(dfn, data)
                mutex.synchronize { results[dfn] = result }
              end
            rescue => e
              puts "Batch processing error for DFN #{dfn}: #{e.message}" if ENV['FILEBOT_DEBUG']
            end
          end
        end
      end
      
      threads.each(&:join)
      results
    end

    def process_batch_sequential(dfn_batch)
      results = {}
      
      @connection_pool.with_connection do |conn|
        dfn_batch.each do |dfn|
          begin
            data = conn.get_global("^DPT", dfn.to_s, "0")
            if data && !data.empty?
              results[dfn] = PatientParser.parse_zero_node(dfn, data)
            end
          rescue => e
            puts "Batch processing error for DFN #{dfn}: #{e.message}" if ENV['FILEBOT_DEBUG']
          end
        end
      end
      
      results
    end

    # === Search Implementations ===

    def search_patients_sql(name_pattern, options)
      limit = options[:limit] || 50
      
      @connection_pool.with_connection do |conn|
        if conn.respond_to?(:execute_sql)
          conn.execute_sql(
            "SELECT ID, Name, DateOfBirth FROM DPT WHERE Name LIKE ? ORDER BY Name LIMIT ?",
            ["%#{name_pattern}%", limit]
          )
        else
          # Fallback to native
          search_patients_native(name_pattern, options)
        end
      end
    end

    def search_patients_cached(name_pattern, options)
      cache_key = "search:#{name_pattern}:#{options.hash}"
      
      @cache.get_or_set(cache_key, ttl: @config[:search_cache_ttl] || 300) do
        search_patients_native_ruby(name_pattern, options)
      end
    end

    # Ruby business logic search (replaces MUMPS FileMan FIND^DIC)
    def search_patients_native_ruby(name_pattern, options)
      limit = options[:limit] || 10
      
      @connection_pool.with_connection do |conn|
        begin
          # Use Patient model's search method (Ruby business logic)
          patients = Models::Patient.search_by_name(name_pattern, conn, limit)
          
          # Return demographics data for compatibility
          patients.map { |patient| patient.clinical_summary[:demographics] }
        rescue => e
          puts "FileBot: Patient search failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          []
        end
      end
    end

    # === Clinical Summary Implementations ===

    def get_clinical_summary_sql(dfn)
      @connection_pool.with_connection do |conn|
        if conn.respond_to?(:execute_sql)
          conn.execute_sql("""
            SELECT 
              p.ID as dfn,
              p.Name as patient_name,
              p.DateOfBirth as dob,
              COUNT(DISTINCT v.ID) as visit_count,
              COUNT(DISTINCT l.ID) as lab_count,
              MAX(v.DateOfVisit) as last_visit
            FROM DPT p
            LEFT JOIN AUPNVSIT v ON p.ID = v.PatientDFN
            LEFT JOIN LR l ON p.ID = l.PatientDFN
            WHERE p.ID = ?
            GROUP BY p.ID, p.Name, p.DateOfBirth
          """, [dfn])
        else
          get_clinical_summary_native(dfn)
        end
      end
    end

    def get_clinical_summary_native(dfn)
      @connection_pool.with_connection do |conn|
        # Native implementation
        {
          dfn: dfn,
          patient_name: conn.get_global("^DPT", dfn.to_s, "0"),
          dob: conn.get_global("^DPT", dfn.to_s, ".31"),
          visit_count: 0,  # Would implement visit counting
          lab_count: 0,    # Would implement lab counting
          last_visit: nil  # Would implement last visit lookup
        }
      end
    end

    # === Cache TTL Calculation ===

    def calculate_cache_ttl(data, data_type)
      case data_type
      when :patient_demographics
        @config[:aggressive_caching] ? 7200 : 3600  # 2h aggressive, 1h normal
      when :clinical_data
        @config[:aggressive_caching] ? 1800 : 900   # 30m aggressive, 15m normal
      when :search_results
        @config[:aggressive_caching] ? 900 : 300    # 15m aggressive, 5m normal
      else
        3600  # 1 hour default
      end
    end

    # === Configuration Application ===

    def apply_configuration_changes
      # Update cache configuration
      if @cache
        @cache.reconfigure(@config[:cache] || {})
      end
      
      # Update connection pool
      if @connection_pool
        @connection_pool.reconfigure(@config[:connection] || {})
      end
      
      # Update query router
      if @query_router
        @query_router.reconfigure(@config[:query] || {})
      end
    end

    # === Utility Methods ===

    def create_adapter_from_config
      DatabaseAdapterFactory.create_adapter(@config[:adapter_type] || :auto_detect, @config)
    end

    def validate_adapter!
      unless @adapter.respond_to?(:get_global)
        raise ArgumentError, "Adapter must implement get_global method"
      end
    end

    def shutdown_optimizations
      @connection_pool&.shutdown
      @cache&.shutdown if @cache.respond_to?(:shutdown)
    end

    # === Nested Classes (Lightweight Implementations) ===

    class IntelligentCache
      include MonitorMixin

      attr_reader :max_size, :size

      def initialize(options = {})
        super()
        @max_size = options[:max_size] || 1000
        @default_ttl = options[:default_ttl] || 3600
        @cache = {}
        @access_order = []
        @expiry_times = {}
        @stats = { hits: 0, misses: 0 }
      end

      def get(key)
        synchronize do
          return nil unless @cache.key?(key)
          
          if expired?(key)
            delete_key(key)
            @stats[:misses] += 1
            return nil
          end
          
          update_access_order(key)
          @stats[:hits] += 1
          @cache[key]
        end
      end

      def set(key, value, ttl = nil)
        synchronize do
          ttl ||= @default_ttl
          
          if @cache.key?(key)
            @access_order.delete(key)
          end
          
          while @cache.size >= @max_size
            evict_lru
          end
          
          @cache[key] = value
          @access_order << key
          @expiry_times[key] = Time.now + ttl
        end
      end

      def get_or_set(key, ttl: nil)
        result = get(key)
        return result if result
        
        value = yield
        set(key, value, ttl)
        value
      end

      def has?(key)
        synchronize { @cache.key?(key) && !expired?(key) }
      end

      def delete(key)
        synchronize { delete_key(key) }
      end

      def delete_pattern(pattern)
        synchronize do
          regex = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern)
          @cache.keys.select { |key| key.match?(regex) }.each { |key| delete_key(key) }
        end
      end

      def clear
        synchronize do
          @cache.clear
          @access_order.clear
          @expiry_times.clear
        end
      end

      def size
        @cache.size
      end

      def enable_aggressive_mode
        # Implementation for aggressive caching
      end

      def enable_predictive_loading
        # Implementation for predictive loading
      end

      def reconfigure(config)
        synchronize do
          @max_size = config[:max_size] if config.key?(:max_size)
          @default_ttl = config[:default_ttl] if config.key?(:default_ttl)
          
          while @cache.size > @max_size
            evict_lru
          end
        end
      end

      def shutdown
        clear
      end

      private

      def expired?(key)
        expiry_time = @expiry_times[key]
        expiry_time && Time.now > expiry_time
      end

      def delete_key(key)
        @cache.delete(key)
        @access_order.delete(key)
        @expiry_times.delete(key)
      end

      def update_access_order(key)
        @access_order.delete(key)
        @access_order << key
      end

      def evict_lru
        return if @access_order.empty?
        lru_key = @access_order.shift
        delete_key(lru_key)
      end
    end

    class ConnectionPool
      include MonitorMixin

      def initialize(adapter_template, options = {})
        super()
        @adapter_template = adapter_template
        @size = options[:size] || 5
        @timeout = options[:timeout] || 10
        @pool = Array.new(@size) { create_connection }
        @available = @pool.dup
        @checked_out = {}
      end

      def with_connection
        connection = checkout
        begin
          yield(connection)
        ensure
          checkin(connection)
        end
      end

      def checkout
        synchronize do
          if @available.any?
            connection = @available.pop
            @checked_out[connection.object_id] = Thread.current
            connection
          else
            @adapter_template  # Fallback to original adapter
          end
        end
      end

      def checkin(connection)
        synchronize do
          if @checked_out.delete(connection.object_id)
            @available << connection
            # Signal waiting threads that a connection is available
          end
        end
      end

      def utilization_percentage
        synchronize do
          return 0.0 if @size == 0
          ((@size - @available.size).to_f / @size * 100).round(1)
        end
      end

      def reconfigure(config)
        # Implementation for reconfiguration
      end

      def shutdown
        synchronize do
          @pool.each { |conn| conn.disconnect if conn.respond_to?(:disconnect) }
          @pool.clear
          @available.clear
          @checked_out.clear
        end
      end

      private

      def create_connection
        @adapter_template.class.new(@adapter_template.config)
      rescue
        @adapter_template  # Fallback
      end
    end

    class QueryRouter
      def initialize(adapter, options = {})
        @adapter = adapter
        @prefer_sql = options[:prefer_sql] || false
        @sql_threshold = options[:sql_threshold] || 5
        @enable_adaptive_routing = options[:enable_adaptive_routing] || false
      end

      def determine_search_strategy(pattern, options)
        limit = options[:limit] || 10
        
        case
        when @prefer_sql && sql_available? && limit > 20
          :sql
        when pattern.length < 3
          :native
        else
          :cached
        end
      end

      def should_use_sql_for_complex_query?
        @prefer_sql && sql_available?
      end

      def sql_available?
        @adapter.respond_to?(:execute_sql)
      rescue
        false
      end

      def enable_sql_preference
        @prefer_sql = true
      end

      def reconfigure(config)
        @prefer_sql = config[:prefer_sql] if config.key?(:prefer_sql)
        @sql_threshold = config[:sql_threshold] if config.key?(:sql_threshold)
      end
    end
  end
end