# frozen_string_literal: true

module FileBot
  # Centralized credentials management for MUMPS databases
  class CredentialsManager
    class << self
      # Get IRIS database configuration
      def iris_config
        @iris_config ||= load_config(:iris)
      end

      # Get YottaDB database configuration
      def yottadb_config
        @yottadb_config ||= load_config(:yottadb)
      end

      # Get GT.M database configuration
      def gtm_config
        @gtm_config ||= load_config(:gtm)
      end

      # Get FileBot configuration
      def filebot_config
        @filebot_config ||= load_filebot_config
      end

      # Clear cached configurations (useful for testing)
      def clear_cache!
        @iris_config = nil
        @yottadb_config = nil
        @gtm_config = nil
        @filebot_config = nil
      end

      private

      def load_config(database_type)
        # Try Rails credentials first
        if Rails.application.credentials.mumps&.public_send(database_type)
          rails_config = Rails.application.credentials.mumps.public_send(database_type)
          normalize_config(rails_config, database_type)
        else
          # Fallback to environment variables
          load_from_environment(database_type)
        end
      end

      def normalize_config(config, database_type)
        defaults = default_config(database_type)

        {
          host: config[:host] || defaults[:host],
          port: (config[:port] || defaults[:port]).to_i,
          namespace: config[:namespace] || defaults[:namespace],
          username: config[:username] || defaults[:username],
          password: config[:password] || defaults[:password]
        }
      end

      def default_config(database_type)
        case database_type
        when :iris
          {
            host: "localhost",
            port: 1972,
            namespace: "USER",
            username: "_SYSTEM",
            password: "passwordpassword"
          }
        when :yottadb
          {
            host: "localhost",
            port: 9080,
            namespace: "DEFAULT",
            username: "ydbuser",
            password: "ydbpassword"
          }
        when :gtm
          {
            host: "localhost",
            port: 9081,
            namespace: "DEFAULT",
            username: "gtmuser",
            password: "gtmpassword"
          }
        else
          raise ArgumentError, "Unknown database type: #{database_type}"
        end
      end

      def load_from_environment(database_type)
        prefix = database_type.to_s.upcase
        defaults = default_config(database_type)

        {
          host: ENV.fetch("#{prefix}_HOST", defaults[:host]),
          port: ENV.fetch("#{prefix}_PORT", defaults[:port]).to_i,
          namespace: ENV.fetch("#{prefix}_NAMESPACE", defaults[:namespace]),
          username: ENV.fetch("#{prefix}_USERNAME", defaults[:username]),
          password: ENV.fetch("#{prefix}_PASSWORD", defaults[:password])
        }
      end

      def load_filebot_config
        # Try Rails credentials first
        if Rails.application.credentials.filebot
          config = Rails.application.credentials.filebot
          {
            default_adapter: (config[:default_adapter] || :iris).to_sym,
            performance_logging: config[:performance_logging] != false,
            healthcare_audit_enabled: config[:healthcare_audit_enabled] != false,
            connection_pool_size: config[:connection_pool_size] || 5,
            connection_timeout: config[:connection_timeout] || 30
          }
        else
          # Environment variable fallbacks
          {
            default_adapter: (ENV.fetch("FILEBOT_DEFAULT_ADAPTER", "iris")).to_sym,
            performance_logging: ENV.fetch("FILEBOT_PERFORMANCE_LOGGING", "true") == "true",
            healthcare_audit_enabled: ENV.fetch("FILEBOT_HEALTHCARE_AUDIT", "true") == "true",
            connection_pool_size: ENV.fetch("FILEBOT_CONNECTION_POOL_SIZE", "5").to_i,
            connection_timeout: ENV.fetch("FILEBOT_CONNECTION_TIMEOUT", "30").to_i
          }
        end
      end
    end
  end
end
