# frozen_string_literal: true

module FileBot
  module Adapters
    # Abstract base adapter that defines the contract for all MUMPS database adapters
    # This interface ensures implementation consistency across different MUMPS platforms
    class BaseAdapter
      # Abstract methods that must be implemented by concrete adapters
      
      # Initialize the adapter with configuration
      # @param config [Hash] Adapter-specific configuration parameters
      def initialize(config = {})
        @config = config
        setup_connection if respond_to?(:setup_connection, true)
      end

      # === Core Global Operations ===
      
      # Get value from global node
      # @param global [String] Global name (e.g., "^DPT")
      # @param subscripts [Array] Variable number of subscripts
      # @return [String, nil] Global value or nil if not set
      def get_global(global, *subscripts)
        raise NotImplementedError, "#{self.class}#get_global must be implemented"
      end

      # Set value in global node
      # @param value [String] Value to set
      # @param global [String] Global name
      # @param subscripts [Array] Variable number of subscripts
      # @return [Boolean] Success status
      def set_global(value, global, *subscripts)
        raise NotImplementedError, "#{self.class}#set_global must be implemented"
      end

      # Get next subscript in order
      # @param global [String] Global name
      # @param subscripts [Array] Current subscripts
      # @return [String, nil] Next subscript or nil if no more
      def order_global(global, *subscripts)
        raise NotImplementedError, "#{self.class}#order_global must be implemented"
      end

      # Check if global node has data (defined)
      # @param global [String] Global name
      # @param subscripts [Array] Variable number of subscripts
      # @return [Integer] 0=undefined, 1=data, 10=descendants, 11=both
      def data_global(global, *subscripts)
        raise NotImplementedError, "#{self.class}#data_global must be implemented"
      end

      # === Advanced Operations ===

      # Execute MUMPS code directly (optional for advanced adapters)
      # @param code [String] MUMPS code to execute
      # @return [String, nil] Execution result
      def execute_mumps(code)
        raise NotImplementedError, "#{self.class}#execute_mumps not supported by this adapter"
      end

      # Lock global node (optional for locking-capable adapters)
      # @param global [String] Global name
      # @param subscripts [Array] Subscripts to lock
      # @param timeout [Integer] Lock timeout in seconds
      # @return [Boolean] Lock acquired successfully
      def lock_global(global, *subscripts, timeout: 30)
        # Default implementation returns true (no-op)
        # Override for adapters that support locking
        true
      end

      # Unlock global node (optional for locking-capable adapters)
      # @param global [String] Global name
      # @param subscripts [Array] Subscripts to unlock
      # @return [Boolean] Unlock successful
      def unlock_global(global, *subscripts)
        # Default implementation returns true (no-op)
        # Override for adapters that support locking
        true
      end

      # === Transaction Support ===

      # Start transaction (optional for transaction-capable adapters)
      # @return [Object] Transaction handle or nil
      def start_transaction
        # Default implementation returns nil (no transactions)
        # Override for adapters that support transactions
        nil
      end

      # Commit transaction (optional for transaction-capable adapters)
      # @param transaction [Object] Transaction handle
      # @return [Boolean] Commit successful
      def commit_transaction(transaction)
        # Default implementation returns true (no-op)
        # Override for adapters that support transactions
        true
      end

      # Rollback transaction (optional for transaction-capable adapters)
      # @param transaction [Object] Transaction handle
      # @return [Boolean] Rollback successful
      def rollback_transaction(transaction)
        # Default implementation returns true (no-op)
        # Override for adapters that support transactions
        true
      end

      # === Adapter Information ===

      # Get adapter type identifier
      # @return [Symbol] Adapter type (e.g., :iris, :yottadb, :gtm)
      def adapter_type
        raise NotImplementedError, "#{self.class}#adapter_type must be implemented"
      end

      # Get adapter version information
      # @return [Hash] Version info with keys: adapter_version, database_version
      def version_info
        {
          adapter_version: "1.0.0",
          database_version: "unknown"
        }
      end

      # Get adapter capabilities
      # @return [Hash] Capabilities hash with boolean values
      def capabilities
        {
          transactions: false,
          locking: false,
          mumps_execution: false,
          concurrent_access: true,
          cross_references: true,
          unicode_support: false
        }
      end

      # Check if adapter is connected and ready
      # @return [Boolean] Connection status
      def connected?
        raise NotImplementedError, "#{self.class}#connected? must be implemented"
      end

      # Close adapter connection and cleanup resources
      # @return [Boolean] Cleanup successful
      def close
        @connected = false
        true
      end

      # === Adapter Validation ===

      # Validate adapter configuration
      # @return [Array<String>] Array of validation errors (empty if valid)
      def validate_config
        errors = []
        errors << "Configuration cannot be nil" if @config.nil?
        errors
      end

      # Test adapter connectivity with database
      # @return [Hash] Test result with :success and :message keys
      def test_connection
        return { success: false, message: "Adapter not connected" } unless connected?
        
        begin
          # Try a simple global operation
          test_global = "^FILEBOT_TEST_#{Time.now.to_i}"
          set_global("test", test_global, "connection")
          result = get_global(test_global, "connection")
          set_global("", test_global, "connection")  # Cleanup
          
          if result == "test"
            { success: true, message: "Connection successful" }
          else
            { success: false, message: "Global operation test failed" }
          end
        rescue => e
          { success: false, message: "Connection test failed: #{e.message}" }
        end
      end

      protected

      attr_reader :config

      # Hook for adapter-specific setup (called during initialization)
      # Override in concrete adapters for custom setup logic
      def setup_connection
        # Default implementation is no-op
        # Override in concrete adapters
      end

      # Validate subscripts for global operations
      # @param subscripts [Array] Subscripts to validate
      # @return [Array<String>] Validated subscripts as strings
      def validate_subscripts(subscripts)
        subscripts.map(&:to_s)
      end

      # Normalize global name (ensure proper format)
      # @param global [String] Global name to normalize
      # @return [String] Normalized global name
      def normalize_global_name(global)
        global = global.to_s
        global.start_with?("^") ? global : "^#{global}"
      end
    end
  end
end