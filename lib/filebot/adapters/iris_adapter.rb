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
        # Use MUMPS execution since direct global methods aren't available
        if subscripts.empty?
          mumps_code = "W $G(#{global})"
        else
          subscript_str = subscripts.map { |s| "\"#{s}\"" }.join(",")
          mumps_code = "W $G(#{global}(#{subscript_str}))"
        end
        
        execute_mumps(mumps_code)
      end

      def set_global(global, *subscripts_and_value)
        value = subscripts_and_value.pop
        subscripts = subscripts_and_value
        
        # Use MUMPS execution for setting globals
        if subscripts.empty?
          mumps_code = "S #{global}=\"#{value}\""
        else
          subscript_str = subscripts.map { |s| "\"#{s}\"" }.join(",")
          mumps_code = "S #{global}(#{subscript_str})=\"#{value}\""
        end
        
        execute_mumps(mumps_code)
      end

      def order_global(global, *subscripts)
        direction = subscripts.last.is_a?(Integer) ? subscripts.pop : 1

        # Use MUMPS $ORDER function
        if subscripts.empty?
          mumps_code = "W $O(#{global}(\"\"))"
        else
          subscript_str = subscripts.map { |s| "\"#{s}\"" }.join(",")
          mumps_code = "W $O(#{global}(#{subscript_str}))"
        end
        
        execute_mumps(mumps_code)
      end

      def data_global(global, *subscripts)
        # Use MUMPS $DATA function
        if subscripts.empty?
          mumps_code = "W $D(#{global})"
        else
          subscript_str = subscripts.map { |s| "\"#{s}\"" }.join(",")
          mumps_code = "W $D(#{global}(#{subscript_str}))"
        end
        
        result = execute_mumps(mumps_code)
        result.to_i if result
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
        !@iris_native.nil? && @iris_native.isConnected rescue false
      end

      def execute_mumps(code)
        # Try different execution methods available on IRISDatabase
        if @iris_native.respond_to?(:execute)
          @iris_native.execute(code)
        elsif @iris_native.respond_to?(:executeUpdate)
          @iris_native.executeUpdate(code)
        else
          # Fallback to simple return for testing
          puts "MUMPS execution not available: #{code}" if ENV['FILEBOT_DEBUG']
          ""
        end
      rescue => e
        puts "MUMPS execution failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        ""
      end

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

        # Import IRIS classes
        java_import "com.intersystems.jdbc.IRISDriver"
        java_import "com.intersystems.binding.IRISDatabase"
        java_import "java.util.Properties"

        puts "FileBot: Establishing IRIS Native API connection" if ENV['FILEBOT_DEBUG']

        # Get credentials from environment configuration
        iris_config = get_iris_credentials

        # First establish JDBC connection
        driver = IRISDriver.new
        properties = Properties.new
        properties.setProperty("user", iris_config[:username])
        properties.setProperty("password", iris_config[:password])

        connection_url = "jdbc:IRIS://#{iris_config[:host]}:#{iris_config[:port]}/#{iris_config[:namespace]}"
        jdbc_connection = driver.connect(connection_url, properties)

        # Then get Native API from JDBC connection
        @iris_native = IRISDatabase.getDatabase(jdbc_connection)

        puts "FileBot: IRIS Native API connection established to #{iris_config[:host]}:#{iris_config[:port]}" if ENV['FILEBOT_DEBUG']
      end

      def get_iris_credentials
        # Use centralized credentials manager
        FileBot::CredentialsManager.iris_config
      end

      def iris_version
        return @iris_version if defined?(@iris_version)
        
        begin
          @iris_version = @iris_native.getServerVersion if @iris_native
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
