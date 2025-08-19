# frozen_string_literal: true

require_relative 'base_adapter'

module FileBot
  module Adapters
    # IRIS database adapter using pure Java Native API
    class IRISAdapter < BaseAdapter
      def initialize(config = {})
        super(config)
      end

      def get_global(global, *subscripts)
        return "" if @iris_native.nil?
        
        # Use Native SDK direct global access
        begin
          # Convert ^GLOBAL format to just GLOBAL for Native SDK
          clean_global = global.sub(/^\^/, '')
          
          # Validate global name (IRIS doesn't allow underscores in many contexts)
          if clean_global.include?('_')
            puts "FileBot: Warning - global name '#{clean_global}' contains underscore, may cause IRIS syntax errors" if ENV['FILEBOT_DEBUG']
            # Convert underscores to valid characters for IRIS
            clean_global = clean_global.gsub('_', 'X')
          end
          
          if subscripts.empty?
            # Get global root
            @iris_native.getString(clean_global)
          else
            # Get global with subscripts
            @iris_native.getString(clean_global, *subscripts)
          end
        rescue => e
          puts "FileBot: Global GET failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          ""
        end
      end

      def set_global(global, *subscripts_and_value)
        return "" if @iris_native.nil?
        
        value = subscripts_and_value.pop
        subscripts = subscripts_and_value
        
        # Use Native SDK direct global access
        begin
          # Convert ^GLOBAL format to just GLOBAL for Native SDK
          clean_global = global.sub(/^\^/, '')
          
          # Validate global name (IRIS doesn't allow underscores in many contexts)
          if clean_global.include?('_')
            puts "FileBot: Warning - global name '#{clean_global}' contains underscore, may cause IRIS syntax errors" if ENV['FILEBOT_DEBUG']
            # Convert underscores to valid characters for IRIS
            clean_global = clean_global.gsub('_', 'X')
          end
          
          if subscripts.empty?
            # Set global root
            @iris_native.set(value, clean_global)
          else
            # Set global with subscripts
            @iris_native.set(value, clean_global, *subscripts)
          end
          
          "OK"
        rescue => e
          puts "FileBot: Global SET failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          ""
        end
      end

      def kill_global(global, *subscripts)
        return false if @iris_native.nil?
        
        begin
          # Convert ^GLOBAL format to just GLOBAL for Native SDK
          clean_global = global.sub(/^\^/, '')
          
          # Validate global name
          if clean_global.include?('_')
            puts "FileBot: Warning - global name '#{clean_global}' contains underscore, may cause IRIS syntax errors" if ENV['FILEBOT_DEBUG']
            clean_global = clean_global.gsub('_', 'X')
          end
          
          if subscripts.empty?
            # Kill entire global
            @iris_native.kill(clean_global)
          else
            # Kill specific subscripted node
            @iris_native.kill(clean_global, *subscripts)
          end
          
          puts "KILL(#{clean_global}#{subscripts.empty? ? '' : ','+subscripts.join(',')}) successful" if ENV['FILEBOT_DEBUG']
          true
        rescue => e
          puts "FileBot: Global KILL failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          false
        end
      end

      def order_global(global, *subscripts)
        return "" if @iris_native.nil?
        begin
          clean_global = global.sub(/^\^/, '')
          
          if subscripts.empty?
            # Get first subscript at root level
            iterator = @iris_native.getIRISIterator(clean_global)
            if iterator.hasNext
              iterator.next
              next_sub = iterator.getSubscriptValue
              puts "ORDER next (first): #{next_sub}" if ENV['FILEBOT_DEBUG']
              next_sub.to_s
            else
              puts "ORDER next: no subscripts found" if ENV['FILEBOT_DEBUG']
              ""
            end
          else
            # Handle multi-level subscripts
            last_subscript = subscripts.last
            parent_subscripts = subscripts[0..-2]
            
            if last_subscript == "0"
              # Get first subscript at this level
              iterator = if parent_subscripts.empty?
                @iris_native.getIRISIterator(clean_global)
              else
                @iris_native.getIRISIterator(clean_global, *parent_subscripts)
              end
              
              if iterator.hasNext
                iterator.next
                next_sub = iterator.getSubscriptValue
                puts "ORDER next (first at level): #{next_sub}" if ENV['FILEBOT_DEBUG']
                next_sub.to_s
              else
                puts "ORDER next: no subscripts at level" if ENV['FILEBOT_DEBUG']
                ""
              end
            else
              # Find next subscript after the current one at this level
              iterator = if parent_subscripts.empty?
                @iris_native.getIRISIterator(clean_global)
              else
                @iris_native.getIRISIterator(clean_global, *parent_subscripts)
              end
              
              found_target = false
              while iterator.hasNext
                iterator.next
                current_sub = iterator.getSubscriptValue.to_s
                
                if found_target
                  puts "ORDER next: #{current_sub}" if ENV['FILEBOT_DEBUG']
                  return current_sub
                elsif current_sub == last_subscript
                  found_target = true
                end
              end
              
              puts "ORDER next: no more subscripts after #{last_subscript}" if ENV['FILEBOT_DEBUG']
              ""
            end
          end
        rescue => e
          puts "ORDER error: #{e.message}" if ENV['FILEBOT_DEBUG']
          ""
        end
      end

      def query_global(global, *subscripts)
        return "" if @iris_native.nil?
        begin
          clean_global = global.sub(/^\^/, '')
          
          # $QUERY returns the next global reference in collating sequence
          # This provides more powerful traversal than $ORDER
          if subscripts.empty?
            # Query at global level
            query_result = @iris_native.queryGet(clean_global)
          else
            # Query with specific subscripts
            query_result = @iris_native.queryGet(clean_global, *subscripts)
          end
          
          # Extract the next reference from query result
          if query_result && query_result.hasNext
            next_ref = query_result.nextSubscript
            puts "QUERY next: #{next_ref}" if ENV['FILEBOT_DEBUG']
            next_ref.to_s
          else
            puts "QUERY: no more references" if ENV['FILEBOT_DEBUG']
            ""
          end
        rescue => e
          puts "QUERY error: #{e.message}" if ENV['FILEBOT_DEBUG']
          ""
        end
      end

      def data_global(global, *subscripts)
        return 0 if @iris_native.nil?
        begin
          clean_global = global.sub(/^\^/, '')
          
          # MUMPS $DATA function returns:
          # 0 = undefined (node does not exist)
          # 1 = defined, has value but no descendants  
          # 10 = defined, has descendants but no value
          # 11 = defined, has both value and descendants
          
          has_value = false
          has_descendants = false
          
          # Check if the node has a value using Native SDK isDefined
          begin
            has_value = if subscripts.empty?
              @iris_native.isDefined(clean_global) 
            else
              @iris_native.isDefined(clean_global, *subscripts)
            end
            
            # Double-check with getString for accuracy
            if has_value
              val = if subscripts.empty?
                @iris_native.getString(clean_global)
              else
                @iris_native.getString(clean_global, *subscripts)
              end
              has_value = !(val.nil? || val.to_s.empty?)
            end
          rescue => e
            puts "DATA value check error: #{e.message}" if ENV['FILEBOT_DEBUG']
            has_value = false
          end
          
          # Check if the node has descendants using iterator
          begin
            iterator = @iris_native.getIRISIterator(clean_global, *subscripts)
            has_descendants = iterator.hasNext
          rescue => e
            puts "DATA descendant check error: #{e.message}" if ENV['FILEBOT_DEBUG']
            has_descendants = false
          end
          
          # Calculate $DATA return value
          data_val = 0
          data_val += 1 if has_value
          data_val += 10 if has_descendants
          
          puts "DATA(#{clean_global}#{subscripts.empty? ? '' : ','+subscripts.join(',')}) = #{data_val}" if ENV['FILEBOT_DEBUG']
          data_val
        rescue => e
          puts "DATA error: #{e.message}" if ENV['FILEBOT_DEBUG']
          0
        end
      end

      # === BaseAdapter Interface Implementation ===

      def adapter_type
        :iris
      end

      def version_info
        {
          adapter_version: "1.0.0",
          database_version: iris_version || "unknown"
        }
      end

      def capabilities
        {
          transactions: true,
          locking: true,
          mumps_execution: true,
          concurrent_access: true,
          cross_references: true,
          unicode_support: true
        }
      end

      def connected?
        !@iris_native.nil? && !@jdbc_connection.nil? && !@jdbc_connection.isClosed rescue false
      end

      # === Benchmark Compatibility Methods ===
      
      # Wrapper for order_global to match benchmark expectations
      def get_next_global(global, *subscripts)
        order_global(global, *subscripts)
      end
      
      # Wrapper for data_global to match benchmark expectations  
      def global_exists(global, *subscripts)
        data_global(global, *subscripts) > 0
      end

      # === Cross-Reference Support (FileMan B Index) ===
      
      def build_cross_reference(file_global, field, value, ien)
        # Create standard FileMan B index: ^GLOBAL("B",VALUE,IEN)=""
        begin
          set_global(file_global, "B", value, ien, "")
          puts "Cross-reference built: #{file_global}(\"B\",\"#{value}\",#{ien})" if ENV['FILEBOT_DEBUG']
          true
        rescue => e
          puts "Cross-reference build failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          false
        end
      end
      
      def find_by_cross_reference(file_global, field, value)
        # Use FileMan B index to find records: ^GLOBAL("B",VALUE,IEN)
        results = []
        begin
          # Check if this value exists in the cross-reference
          data_val = data_global(file_global, "B", value)
          if data_val >= 10
            # Walk through all IENs for this value
            current_ien = "0"
            while true
              next_ien = order_global(file_global, "B", value, current_ien)
              break if next_ien.empty?
              
              # Verify this is actually an IEN (not another value)
              if next_ien.match(/^\d+$/)
                results << next_ien
              end
              current_ien = next_ien
              break if results.length > 100  # Safety limit
            end
          end
        rescue => e
          puts "Cross-reference lookup failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        end
        
        results
      end
      
      def delete_cross_reference(file_global, field, value, ien)
        # Remove from FileMan B index
        begin
          kill_global(file_global, "B", value, ien)
          puts "Cross-reference deleted: #{file_global}(\"B\",\"#{value}\",#{ien})" if ENV['FILEBOT_DEBUG']
          true
        rescue => e
          puts "Cross-reference delete failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          false
        end
      end

      # FileBot no longer executes MUMPS/ObjectScript code
      # All business logic is now implemented in Ruby
      # IRIS is used as pure data layer only
      
      # Real ObjectScript/MUMPS execution using IRIS Native SDK
      def execute_mumps(mumps_code)
        return "" if @iris_native.nil?
        
        begin
          # Use IRIS Native SDK to execute ObjectScript directly
          # This bypasses SQL and executes real MUMPS/ObjectScript code
          result = @iris_native.classMethodValue("%SYSTEM.Process", "Evaluate", mumps_code)
          result.toString
        rescue => e
          puts "FileBot: ObjectScript execution failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          # Fallback: try direct routine execution if available
          begin
            # Alternative: use procedure call for FileMan routines
            @iris_native.procedure("FileManCall", mumps_code)
          rescue => e2
            puts "FileBot: Fallback execution failed: #{e2.message}" if ENV['FILEBOT_DEBUG']
            ""
          end
        end
      end
      
      private
      
      # Helper methods for IRIS global operations
      
      public

      def lock_global(global, *subscripts, timeout: 30)
        lock_ref = build_lock_reference(global, *subscripts)
        @iris_native.lock(lock_ref, timeout) == 1
      rescue => e
        puts "Lock failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        false
      end

      def unlock_global(global, *subscripts)
        lock_ref = build_lock_reference(global, *subscripts)
        @iris_native.unlock(lock_ref)
        true
      rescue => e
        puts "Unlock failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        false
      end

      def start_transaction
        @iris_native.startTransaction
      rescue => e
        puts "Transaction start failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        nil
      end

      def commit_transaction(transaction)
        @iris_native.commitTransaction(transaction)
        true
      rescue => e
        puts "Transaction commit failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        false
      end

      def rollback_transaction(transaction)
        @iris_native.rollbackTransaction(transaction)
        true
      rescue => e
        puts "Transaction rollback failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        false
      end

      private

      # Override setup_connection from BaseAdapter
      def setup_connection
        setup_native_connection
      end

      def setup_native_connection
        require "java"

        # Load IRIS JARs using the JAR manager
        FileBot::JarManager.load_iris_jars!

        # Import IRIS classes for Native SDK (not just JDBC)
        java_import "com.intersystems.jdbc.IRISDriver"
        java_import "com.intersystems.jdbc.IRISConnection"
        java_import "com.intersystems.jdbc.IRIS"  # Native SDK class
        java_import "java.util.Properties"

        puts "FileBot: Establishing IRIS Native SDK connection" if ENV['FILEBOT_DEBUG']

        # Get credentials from environment configuration
        iris_config = get_iris_credentials

        # Step 1: Create JDBC connection (required for Native SDK)
        driver = IRISDriver.new
        properties = Properties.new
        properties.setProperty("user", iris_config[:username])
        properties.setProperty("password", iris_config[:password])

        connection_url = "jdbc:IRIS://#{iris_config[:host]}:#{iris_config[:port]}/#{iris_config[:namespace]}"
        @jdbc_connection = driver.connect(connection_url, properties)
        
        # Step 2: Create Native SDK object from JDBC connection
        @iris_native = IRIS.createIRIS(@jdbc_connection)

        puts "FileBot: IRIS Native SDK connection established to #{iris_config[:host]}:#{iris_config[:port]}" if ENV['FILEBOT_DEBUG']
        puts "FileBot: Native SDK object: #{@iris_native.class.name}" if ENV['FILEBOT_DEBUG']
      end

      def get_iris_credentials
        # Use centralized credentials manager
        FileBot::CredentialsManager.iris_config
      end

      def iris_version
        return @iris_version if defined?(@iris_version)
        
        begin
          # Try to get version from JDBC connection metadata
          if @iris_native
            metadata = @iris_native.getMetaData
            @iris_version = "#{metadata.getDatabaseProductName} #{metadata.getDatabaseProductVersion}"
          else
            @iris_version = "unknown"
          end
        rescue => e
          puts "Could not get IRIS version: #{e.message}" if ENV['FILEBOT_DEBUG']
          @iris_version = "unknown"
        end
        
        @iris_version
      end

      def build_lock_reference(global, *subscripts)
        ref = global.dup
        subscripts.each { |sub| ref << "(\"#{sub}\")" } unless subscripts.empty?
        ref
      end
    end
  end
end
