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

      def order_global(global, *subscripts)
        return "" if @iris_native.nil?
        
        direction = subscripts.last.is_a?(Integer) ? subscripts.pop : 1
        
        # Use Native SDK iterator methods
        begin
          clean_global = global.sub(/^\^/, '')
          
          iter = subscripts.empty? ? @iris_native.iterator(clean_global) : @iris_native.iterator(clean_global, *subscripts)
          if iter && iter.hasNext
            next_val = iter.next
            puts 'ORDER next: ' + next_val.to_s if ENV['FILEBOT_DEBUG']
            next_val
          else
            puts 'ORDER failed or no next for ' + clean_global + ' ' + subscripts.inspect if ENV['FILEBOT_DEBUG']
            ""
          end
        rescue => e
          puts 'ORDER error: ' + e.message if ENV['FILEBOT_DEBUG']
          ""
        end
      end

      def data_global(global, *subscripts)
        return 0 if @iris_native.nil?
        begin
          clean_global = global.sub(/^\^/, '')
          defined = subscripts.empty? ? @iris_native.isDefined(clean_global) : @iris_native.isDefined(clean_global, *subscripts)
          puts 'DATA for ' + clean_global + ' ' + subscripts.inspect + ': ' + defined.to_s if ENV['FILEBOT_DEBUG']
          defined ? 1 : 0
        rescue => e
          puts 'DATA error: ' + e.message if ENV['FILEBOT_DEBUG']
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
