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
          
          if subscripts.empty?
            # Get first subscript
            iter = @iris_native.iterator(clean_global)
            iter.hasNext ? iter.next : ""
          else
            # Get next subscript after given subscripts
            iter = @iris_native.iterator(clean_global, *subscripts)
            iter.hasNext ? iter.next : ""
          end
        rescue => e
          puts "FileBot: Global ORDER failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          ""
        end
      end

      def data_global(global, *subscripts)
        return 0 if @iris_native.nil?
        
        # Use Native SDK isDefined method
        begin
          clean_global = global.sub(/^\^/, '')
          
          if subscripts.empty?
            @iris_native.isDefined(clean_global) ? 1 : 0
          else
            @iris_native.isDefined(clean_global, *subscripts) ? 1 : 0
          end
        rescue => e
          puts "FileBot: Global DATA failed: #{e.message}" if ENV['FILEBOT_DEBUG']
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

      def execute_mumps(code)
        return "" if @iris_native.nil?
        
        # Use Native SDK for ObjectScript execution when possible
        clean_code = code.strip.gsub(/\n\s*/, " ")
        puts "FileBot: Executing MUMPS: #{clean_code}" if ENV['FILEBOT_DEBUG']
        
        begin
          # Method 1: Handle simple WRITE commands directly
          if clean_code.match(/^W[RITE]*\s+"([^"]+)"$/)
            # Simple quoted string write
            return $1
          elsif clean_code.match(/^W[RITE]*\s+\$G[ET]*\((.+)\)$/)
            # WRITE $GET(global) - use our get_global method
            get_expression = $1
            if get_expression.match(/^\^(\w+)\((.+)\)$/)
              global_name = "^#{$1}"
              subscripts = parse_subscripts($2)
              return get_global(global_name, *subscripts)
            elsif get_expression.match(/^\^(\w+)$/)
              return get_global("^#{$1}")
            end
          elsif clean_code.match(/^S[ET]*\s+\^(\w+)\((.+)\)="(.+)"$/)
            # SET ^GLOBAL(subscripts)=value - use our set_global method
            global_name = "^#{$1}"
            subscripts = parse_subscripts($2)
            value = $3
            set_global(global_name, *subscripts, value)
            return "OK"
          end
          
          # Method 2: Try Native SDK function calls for ObjectScript functions
          begin
            # For system functions like $HOROLOG, we can call them via functionString
            if clean_code.match(/^W[RITE]*\s+(\$\w+.*)$/)
              function_expr = $1
              if @iris_native.respond_to?(:functionString)
                result = @iris_native.functionString(function_expr)
                puts "FileBot: Native SDK function result: #{result}" if ENV['FILEBOT_DEBUG']
                return result.to_s
              end
            end
          rescue => native_error
            puts "FileBot: Native SDK function failed: #{native_error.message}" if ENV['FILEBOT_DEBUG']
          end
          
          # If all methods fail, return empty string
          ""
          
        rescue => e
          puts "FileBot: MUMPS execution failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          ""
        end
      end
      
      private
      
      def parse_subscripts(subscripts_str)
        # Parse MUMPS subscripts: "key1","key2",123 -> ["key1", "key2", 123]
        subscripts_str.split(',').map do |sub|
          sub = sub.strip
          if sub.match(/^"([^"]*)"$/)
            $1  # Remove quotes
          elsif sub.match(/^\d+$/)
            sub.to_i  # Convert to integer
          else
            sub  # Keep as string
          end
        end
      end
      
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
