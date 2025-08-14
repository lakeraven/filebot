# Optimized global access methods for FileBot
# These methods implement the optimization strategies identified in the analysis

module FileBot
  module Adapters
    class IRISAdapter
      # Optimized get_global method with minimal overhead
      def get_global_fast(global, *subscripts)
        # Optimization 1: Fast string processing instead of regex
        clean_global = global.start_with?('^') ? global[1..-1] : global
        
        # Optimization 2: Direct call pattern for common cases
        case subscripts.length
        when 0
          @iris_native.getString(clean_global)
        when 1
          @iris_native.getString(clean_global, subscripts[0])
        when 2
          @iris_native.getString(clean_global, subscripts[0], subscripts[1])
        when 3
          @iris_native.getString(clean_global, subscripts[0], subscripts[1], subscripts[2])
        else
          @iris_native.getString(clean_global, *subscripts)
        end
      rescue => e
        puts "FileBot: Optimized GET failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        ""
      end

      # Optimized set_global method
      def set_global_fast(global, *subscripts_and_value)
        value = subscripts_and_value.pop
        subscripts = subscripts_and_value
        
        # Fast string processing
        clean_global = global.start_with?('^') ? global[1..-1] : global
        
        # Direct call patterns for common cases
        case subscripts.length
        when 0
          @iris_native.set(value, clean_global)
        when 1
          @iris_native.set(value, clean_global, subscripts[0])
        when 2
          @iris_native.set(value, clean_global, subscripts[0], subscripts[1])
        when 3
          @iris_native.set(value, clean_global, subscripts[0], subscripts[1], subscripts[2])
        else
          @iris_native.set(value, clean_global, *subscripts)
        end
        
        "OK"
      rescue => e
        puts "FileBot: Optimized SET failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        ""
      end

      # Batch operations for multiple keys
      def get_globals_batch(global, keys_array)
        clean_global = global.start_with?('^') ? global[1..-1] : global
        results = {}
        
        keys_array.each do |key|
          begin
            results[key] = @iris_native.getString(clean_global, key)
          rescue => e
            results[key] = nil
            puts "FileBot: Batch GET failed for #{key}: #{e.message}" if ENV['FILEBOT_DEBUG']
          end
        end
        
        results
      end

      # Batch set operations
      def set_globals_batch(global, key_value_hash)
        clean_global = global.start_with?('^') ? global[1..-1] : global
        results = {}
        
        key_value_hash.each do |key, value|
          begin
            @iris_native.set(value, clean_global, key)
            results[key] = "OK"
          rescue => e
            results[key] = "ERROR"
            puts "FileBot: Batch SET failed for #{key}: #{e.message}" if ENV['FILEBOT_DEBUG']
          end
        end
        
        results
      end

      # Specialized method for patient data (common healthcare pattern)
      def get_patient_global_fast(dfn, node = "0")
        # Highly optimized for common ^DPT(dfn,0) pattern
        @iris_native.getString("DPT", dfn, node)
      rescue => e
        puts "FileBot: Patient GET failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        ""
      end

      def set_patient_global_fast(dfn, node, data)
        # Highly optimized for ^DPT(dfn,node) pattern
        @iris_native.set(data, "DPT", dfn, node)
        "OK"
      rescue => e
        puts "FileBot: Patient SET failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        ""
      end

      # Connection status caching
      def initialize_connection_cache
        @connection_cached_status = nil
        @last_connection_check = nil
      end

      def connected_cached?
        now = Time.now
        
        # Re-check connection status every 30 seconds or on first call
        if @last_connection_check.nil? || (now - @last_connection_check) > 30
          @connection_cached_status = connected?
          @last_connection_check = now
        end
        
        @connection_cached_status
      end
    end
  end
end