# frozen_string_literal: true

module FileBot
  module Adapters
    # IRIS database adapter using pure Java Native API
    class IRISAdapter
      def initialize
        setup_native_connection
      end

      def get_global(global, *subscripts)
        # For IRIS native API, we need to handle the method calls properly
        case subscripts.length
        when 1
          result = @iris_native.getString(global, subscripts[0])
        when 2
          result = @iris_native.getString(global, subscripts[0], subscripts[1])
        when 3
          result = @iris_native.getString(global, subscripts[0], subscripts[1], subscripts[2])
        else
          # Fallback for more subscripts
          result = @iris_native.getString(global, *subscripts)
        end
        result&.to_s
      end

      def set_global(value, global, *subscripts)
        case subscripts.length
        when 1
          @iris_native.setString(value.to_s, global, subscripts[0])
        when 2
          @iris_native.setString(value.to_s, global, subscripts[0], subscripts[1])
        when 3
          @iris_native.setString(value.to_s, global, subscripts[0], subscripts[1], subscripts[2])
        else
          @iris_native.setString(value.to_s, global, *subscripts)
        end
      end

      def order_global(global, *subscripts)
        direction = subscripts.last.is_a?(Integer) ? subscripts.pop : 1

        case subscripts.length
        when 1
          result = @iris_native.orderNext(global, subscripts[0])
        when 2
          result = @iris_native.orderNext(global, subscripts[0], subscripts[1])
        else
          result = @iris_native.orderNext(global, *subscripts)
        end
        result&.to_s
      end

      def data_global(global, *subscripts)
        case subscripts.length
        when 1
          @iris_native.isDefined(global, subscripts[0])
        when 2
          @iris_native.isDefined(global, subscripts[0], subscripts[1])
        else
          @iris_native.isDefined(global, *subscripts)
        end
      end

      private

      def setup_native_connection
        require "java"

        # Load IRIS JARs using the JAR manager
        FileBot::JarManager.load_iris_jars!

        # Import IRIS classes
        java_import "com.intersystems.jdbc.IRISDriver"
        java_import "com.intersystems.binding.IRISDatabase"
        java_import "java.util.Properties"

        Rails.logger.info "FileBot: Establishing IRIS Native API connection"

        # Get credentials from Rails encrypted credentials
        iris_config = get_iris_credentials

        # Create JDBC connection with encrypted credentials
        driver = IRISDriver.new
        properties = Properties.new
        properties.setProperty("user", iris_config[:username])
        properties.setProperty("password", iris_config[:password])

        connection_url = "jdbc:IRIS://#{iris_config[:host]}:#{iris_config[:port]}/#{iris_config[:namespace]}"
        jdbc_connection = driver.connect(connection_url, properties)

        # Get native database object from JDBC connection
        @iris_native = IRISDatabase.getDatabase(jdbc_connection)

        Rails.logger.info "FileBot: IRIS Native API connection established to #{iris_config[:host]}:#{iris_config[:port]}"
      end

      def get_iris_credentials
        # Use centralized credentials manager
        FileBot::CredentialsManager.iris_config
      end
    end
  end
end
