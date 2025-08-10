# frozen_string_literal: true

module FileBot
  # Registry for managing and discovering MUMPS database adapters
  # Supports both built-in and plugin adapters with dynamic loading
  class AdapterRegistry
    class << self
      # Get all registered adapters
      # @return [Hash] Hash of adapter_name => adapter_class
      def adapters
        @adapters ||= {}
      end

      # Register an adapter
      # @param name [Symbol] Adapter identifier (e.g., :iris, :yottadb)
      # @param adapter_class [Class] Adapter class implementing BaseAdapter
      # @param options [Hash] Optional metadata about the adapter
      def register(name, adapter_class, options = {})
        validate_adapter_class!(adapter_class)
        
        adapters[name.to_sym] = {
          class: adapter_class,
          name: name.to_s,
          description: options[:description] || "#{name.to_s.upcase} MUMPS Database Adapter",
          version: options[:version] || "1.0.0",
          priority: options[:priority] || 0,
          auto_detect: options[:auto_detect] || false
        }

        puts "FileBot: Registered adapter '#{name}' (#{adapter_class})" if ENV['FILEBOT_DEBUG']
      end

      # Unregister an adapter
      # @param name [Symbol] Adapter identifier
      def unregister(name)
        removed = adapters.delete(name.to_sym)
        puts "FileBot: Unregistered adapter '#{name}'" if removed && ENV['FILEBOT_DEBUG']
        removed
      end

      # Get adapter class by name
      # @param name [Symbol] Adapter identifier
      # @return [Class, nil] Adapter class or nil if not found
      def get(name)
        adapter_info = adapters[name.to_sym]
        adapter_info&.dig(:class)
      end

      # Create adapter instance
      # @param name [Symbol] Adapter identifier
      # @param config [Hash] Configuration for adapter
      # @return [BaseAdapter] Configured adapter instance
      def create(name, config = {})
        adapter_class = get(name)
        raise ArgumentError, "Unknown adapter: #{name}" unless adapter_class

        adapter_class.new(config)
      end

      # List all available adapters
      # @return [Array<Hash>] Array of adapter information hashes
      def list
        adapters.values.sort_by { |info| -info[:priority] }
      end

      # Auto-detect available adapters
      # @return [Array<Symbol>] Array of available adapter names
      def auto_detect
        available = []
        
        adapters.each do |name, info|
          next unless info[:auto_detect]
          
          begin
            adapter = create(name, {})
            if adapter.connected?
              available << name
            end
          rescue => e
            puts "Auto-detect failed for #{name}: #{e.message}" if ENV['FILEBOT_DEBUG']
          end
        end
        
        available.sort_by { |name| adapters[name][:priority] }.reverse
      end

      # Get recommended adapter (highest priority available)
      # @return [Symbol, nil] Recommended adapter name or nil
      def recommended
        auto_detect.first
      end

      # Clear all registered adapters
      def clear!
        @adapters = {}
        puts "FileBot: Cleared all adapter registrations" if ENV['FILEBOT_DEBUG']
      end

      # Load built-in adapters
      def load_builtin_adapters!
        # Load and register IRIS adapter
        begin
          require_relative 'adapters/iris_adapter'
          register(:iris, Adapters::IRISAdapter, {
            description: "InterSystems IRIS Database Adapter",
            version: "1.0.0",
            priority: 100,
            auto_detect: true
          })
        rescue LoadError => e
          puts "Could not load IRIS adapter: #{e.message}" if ENV['FILEBOT_DEBUG']
        end

        # Load and register YottaDB adapter (stub)
        begin
          require_relative 'adapters/yottadb_adapter'
          register(:yottadb, Adapters::YottaDBAdapter, {
            description: "YottaDB Database Adapter",
            version: "1.0.0-stub",
            priority: 90,
            auto_detect: false  # Disabled until implemented
          })
        rescue LoadError => e
          puts "Could not load YottaDB adapter: #{e.message}" if ENV['FILEBOT_DEBUG']
        end

        # Load and register GT.M adapter (stub)
        begin
          require_relative 'adapters/gtm_adapter'
          register(:gtm, Adapters::GTMAdapter, {
            description: "GT.M Database Adapter",
            version: "1.0.0-stub", 
            priority: 80,
            auto_detect: false  # Disabled until implemented
          })
        rescue LoadError => e
          puts "Could not load GT.M adapter: #{e.message}" if ENV['FILEBOT_DEBUG']
        end

        puts "FileBot: Loaded #{adapters.size} built-in adapters" if ENV['FILEBOT_DEBUG']
      end

      # Load plugin adapters from specified directory
      # @param plugin_dir [String] Directory containing plugin files
      def load_plugins!(plugin_dir = nil)
        plugin_dirs = [
          plugin_dir,
          File.expand_path("../filebot_plugins", __dir__),
          File.expand_path("~/.filebot/plugins"),
          "/usr/local/lib/filebot/plugins",
          ENV['FILEBOT_PLUGIN_DIR']
        ].compact.select { |dir| Dir.exist?(dir) }

        loaded_count = 0
        
        plugin_dirs.each do |dir|
          puts "FileBot: Loading plugins from #{dir}" if ENV['FILEBOT_DEBUG']
          
          Dir.glob(File.join(dir, "*_adapter.rb")).each do |plugin_file|
            begin
              load plugin_file
              loaded_count += 1
              puts "FileBot: Loaded plugin #{File.basename(plugin_file)}" if ENV['FILEBOT_DEBUG']
            rescue => e
              puts "Failed to load plugin #{plugin_file}: #{e.message}" if ENV['FILEBOT_DEBUG']
            end
          end
        end

        puts "FileBot: Loaded #{loaded_count} plugin adapters" if ENV['FILEBOT_DEBUG'] && loaded_count > 0
      end

      # Initialize registry with all available adapters
      def initialize!
        clear!
        load_builtin_adapters!
        load_plugins!
      end

      private

      # Validate that a class properly implements the BaseAdapter interface
      # @param adapter_class [Class] Class to validate
      def validate_adapter_class!(adapter_class)
        unless adapter_class.is_a?(Class)
          raise ArgumentError, "Adapter must be a class"
        end

        # Check if it's a subclass of BaseAdapter
        begin
          require_relative 'adapters/base_adapter'
          unless adapter_class.ancestors.include?(Adapters::BaseAdapter)
            puts "Warning: Adapter #{adapter_class} does not inherit from BaseAdapter" if ENV['FILEBOT_DEBUG']
          end
        rescue LoadError
          # BaseAdapter not available, skip validation
        end

        # Check for required methods
        required_methods = [:get_global, :set_global, :order_global, :data_global, :adapter_type, :connected?]
        missing_methods = required_methods.reject { |method| adapter_class.method_defined?(method) }
        
        unless missing_methods.empty?
          raise ArgumentError, "Adapter #{adapter_class} missing required methods: #{missing_methods.join(', ')}"
        end
      end
    end
  end
end