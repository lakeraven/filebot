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
        !@iris_native.nil? && !@iris_native.isClosed rescue false
      end

      def execute_mumps(code)
        return "" if @iris_native.nil?
        
        # Use same MUMPS execution pattern as working rpms_redux
        clean_code = code.strip.gsub(/\n\s*/, " ")
        puts "FileBot: Executing MUMPS: #{clean_code}" if ENV['FILEBOT_DEBUG']
        
        begin
          # Method 1: Try direct SQL execution for simple MUMPS commands
          if clean_code.match(/^W[RITE]*\s+(.+)$/)
            # Handle WRITE commands
            expression = $1
            if expression.match(/^"([^"]+)"$/)
              # Simple quoted string
              return $1
            elsif expression.match(/^\$G[ET]*\((.+)\)$/)
              # Handle $GET() function calls
              get_expression = $1
              return execute_get_operation(get_expression)
            end
          elsif clean_code.match(/^S[ET]*\s+(.+)$/)
            # Handle SET commands
            set_expression = $1
            return execute_set_operation(set_expression)
          end
          
          # Method 2: Use JDBC statement execution
          stmt = @iris_native.createStatement
          begin
            # Try different SQL wrapper approaches
            sql_approaches = [
              "SELECT %SYSTEM_SQL.Execute('#{clean_code.gsub("'", "''")}')",
              "DO $SYSTEM.SQL.Execute('#{clean_code.gsub("'", "''")}')"
            ]
            
            sql_approaches.each do |sql|
              begin
                puts "FileBot: Trying SQL: #{sql}" if ENV['FILEBOT_DEBUG']
                result_set = stmt.executeQuery(sql)
                result = ""
                if result_set.next
                  result = result_set.getString(1) || ""
                end
                result_set.close
                puts "FileBot: SQL execution result: #{result}" if ENV['FILEBOT_DEBUG']
                return result
              rescue => e
                puts "FileBot: SQL approach failed: #{e.message}" if ENV['FILEBOT_DEBUG']
                next
              end
            end
            
            # Method 3: Try direct execute
            stmt.execute(clean_code)
            return ""
            
          ensure
            stmt.close
          end
          
        rescue => e
          puts "FileBot: MUMPS execution failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          ""
        end
      end
      
      private
      
      def execute_get_operation(get_expression)
        # Handle $GET(^GLOBAL(subscripts)) operations
        if get_expression.match(/^\^(\w+)\((.+)\)$/)
          global_name = $1
          subscripts = $2
          puts "FileBot: GET operation: ^#{global_name}(#{subscripts})" if ENV['FILEBOT_DEBUG']
          
          # Use same pattern as working rpms_redux: SELECT %SYSTEM_SQL.Execute('WRITE $GET(...)')
          sql = "SELECT %SYSTEM_SQL.Execute('WRITE $GET(^#{global_name}(#{subscripts}))')"
          stmt = @iris_native.createStatement
          begin
            result_set = stmt.executeQuery(sql)
            result = ""
            if result_set.next
              result = result_set.getString(1) || ""
            end
            result_set.close
            puts "FileBot: GET result: #{result}" if ENV['FILEBOT_DEBUG']
            return result
          ensure
            stmt.close
          end
        end
        
        ""
      end
      
      def execute_set_operation(set_expression)
        # Handle SET ^GLOBAL(subscripts)=value operations  
        if set_expression.match(/^\^(\w+)\((.+)\)=(.+)$/)
          global_name = $1
          subscripts = $2
          value = $3
          puts "FileBot: SET operation: ^#{global_name}(#{subscripts})=#{value}" if ENV['FILEBOT_DEBUG']
          
          # Clean up value (remove quotes if present)
          cleaned_value = value.gsub(/^"/, '').gsub(/"$/, '')
          
          # Use direct SQL to set the global
          sql = "DO $SYSTEM.SQL.Execute('SET ^#{global_name}(#{subscripts})=\"#{cleaned_value}\"')"
          stmt = @iris_native.createStatement
          begin
            stmt.execute(sql)
            puts "FileBot: SET operation completed" if ENV['FILEBOT_DEBUG']
            return ""
          ensure
            stmt.close
          end
        end
        
        ""
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

        # Import IRIS classes (using same pattern as working rpms_redux)
        java_import "com.intersystems.jdbc.IRISDriver"
        java_import "com.intersystems.jdbc.IRISConnection"
        java_import "java.util.Properties"

        puts "FileBot: Establishing IRIS JDBC connection for native operations" if ENV['FILEBOT_DEBUG']

        # Get credentials from environment configuration
        iris_config = get_iris_credentials

        # Establish JDBC connection using same pattern as rpms_redux
        driver = IRISDriver.new
        properties = Properties.new
        properties.setProperty("user", iris_config[:username])
        properties.setProperty("password", iris_config[:password])

        connection_url = "jdbc:IRIS://#{iris_config[:host]}:#{iris_config[:port]}/#{iris_config[:namespace]}"
        
        # Store the JDBC connection directly (like rpms_redux does)
        @iris_native = driver.connect(connection_url, properties)

        puts "FileBot: IRIS JDBC connection established to #{iris_config[:host]}:#{iris_config[:port]}" if ENV['FILEBOT_DEBUG']
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
