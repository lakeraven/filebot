# frozen_string_literal: true

module FileBot
  # Modern factory for creating MUMPS database adapters with plugin architecture
  # Uses the adapter registry for dynamic adapter discovery and loading
  class DatabaseAdapterFactory
    class << self
      # Create adapter by type with configuration
      # @param type [Symbol] Adapter type (:iris, :yottadb, :gtm, :auto_detect) or custom adapter name
      # @param config [Hash] Configuration parameters for the adapter
      # @return [BaseAdapter] Configured adapter instance
      def create_adapter(type = :auto_detect, config = {})
        ensure_registry_initialized!

        case type
        when :auto_detect
          auto_detect_adapter(config)
        else
          create_named_adapter(type, config)
        end
      end

      # List all available adapters
      # @return [Array<Hash>] Array of adapter information
      def available_adapters
        ensure_registry_initialized!
        AdapterRegistry.list
      end

      # Get adapter information
      # @param type [Symbol] Adapter type
      # @return [Hash, nil] Adapter information or nil if not found
      def adapter_info(type)
        ensure_registry_initialized!
        adapters = AdapterRegistry.adapters
        adapters[type.to_sym]
      end

      # Test adapter connectivity
      # @param type [Symbol] Adapter type
      # @param config [Hash] Configuration parameters
      # @return [Hash] Test result with :success and :message keys
      def test_adapter(type, config = {})
        begin
          adapter = create_adapter(type, config)
          adapter.test_connection
        rescue => e
          { success: false, message: "Adapter creation failed: #{e.message}" }
        end
      end

      # Register a custom adapter
      # @param name [Symbol] Adapter identifier
      # @param adapter_class [Class] Adapter class
      # @param options [Hash] Adapter metadata
      def register_adapter(name, adapter_class, options = {})
        ensure_registry_initialized!
        AdapterRegistry.register(name, adapter_class, options)
      end

      # Check if specific adapter type is available
      # @param type [Symbol] Adapter type to check
      # @return [Boolean] True if adapter is available and functional
      def adapter_available?(type)
        test_result = test_adapter(type)
        test_result[:success]
      end

      private

      def ensure_registry_initialized!
        @registry_initialized ||= begin
          AdapterRegistry.initialize!
          true
        end
      end

      def auto_detect_adapter(config = {})
        available = AdapterRegistry.auto_detect
        
        if available.empty?
          # Fallback to manual detection for legacy compatibility
          return legacy_auto_detect(config)
        end

        # Use highest priority available adapter
        adapter_name = available.first
        puts "FileBot: Auto-detected #{adapter_name} database" if ENV['FILEBOT_DEBUG']
        
        AdapterRegistry.create(adapter_name, config)
      end

      def create_named_adapter(type, config = {})
        adapter = AdapterRegistry.get(type)
        
        unless adapter
          raise ArgumentError, "Unknown adapter type: #{type}. Available: #{AdapterRegistry.adapters.keys.join(', ')}"
        end

        AdapterRegistry.create(type, config)
      end

      # Legacy auto-detection for backwards compatibility
      def legacy_auto_detect(config = {})
        # Try IRIS first (most common in healthcare)
        if iris_available?
          puts "FileBot: Auto-detected IRIS database (legacy)" if ENV['FILEBOT_DEBUG']
          return AdapterRegistry.create(:iris, config) if AdapterRegistry.get(:iris)
        end
        
        if yottadb_available?
          puts "FileBot: Auto-detected YottaDB (legacy)" if ENV['FILEBOT_DEBUG']
          return AdapterRegistry.create(:yottadb, config) if AdapterRegistry.get(:yottadb)
        end
        
        if gtm_available?
          puts "FileBot: Auto-detected GT.M (legacy)" if ENV['FILEBOT_DEBUG']
          return AdapterRegistry.create(:gtm, config) if AdapterRegistry.get(:gtm)
        end

        raise "FileBot: No supported MUMPS database detected"
      end

      def iris_available?
        # Check for IRIS JDBC driver availability
        begin
          require "java"
          java_import "com.intersystems.jdbc.IRISDriver"
          java_import "com.intersystems.binding.IRISDatabase"

          # Get credentials from centralized manager
          iris_config = FileBot::CredentialsManager.iris_config

          # Try to establish connection with credentials
          test_connection = IRISDriver.new.connect(
            "jdbc:IRIS://#{iris_config[:host]}:#{iris_config[:port]}/#{iris_config[:namespace]}",
            java.util.Properties.new.tap do |props|
              props.setProperty("user", iris_config[:username])
              props.setProperty("password", iris_config[:password])
            end
          )
          test_connection.close if test_connection
          true
        rescue => e
          puts "IRIS not available: #{e.message}" if ENV['FILEBOT_DEBUG']
          false
        end
      end

      def yottadb_available?
        # Check for YottaDB installation
        system("which ydb > /dev/null 2>&1") ||
        File.exist?("/usr/local/lib/yottadb") ||
        !ENV["ydb_dir"].nil?
      end

      def gtm_available?
        # Check for GT.M installation
        system("which gtm > /dev/null 2>&1") ||
        File.exist?("/usr/lib/fis-gtm") ||
        !ENV["gtm_dir"].nil?
      end
    end
  end
end