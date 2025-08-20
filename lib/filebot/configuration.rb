# frozen_string_literal: true

module FileBot
  # Centralized configuration management with adapter-agnostic design
  # Supports multiple configuration sources and validation
  class Configuration
    attr_reader :config_data, :sources

    def initialize(sources = nil)
      @sources = sources || default_sources
      @config_data = {}
      @loaded = false
    end

    # Load configuration from all sources
    def load!
      return self if @loaded

      @config_data = {}
      
      @sources.each do |source|
        source_data = load_source(source)
        @config_data = deep_merge(@config_data, source_data) if source_data
      end

      validate_config!
      @loaded = true
      
      self
    end

    # Get configuration value with dot notation support
    # @param key [String] Configuration key (e.g., "adapters.iris.host")
    # @param default [Object] Default value if key not found
    # @return [Object] Configuration value
    def get(key, default = nil)
      load! unless @loaded
      
      keys = key.split('.')
      value = keys.reduce(@config_data) do |hash, k|
        hash.is_a?(Hash) ? hash[k.to_sym] : nil
      end
      
      value.nil? ? default : value
    end

    # Set configuration value with dot notation support
    # @param key [String] Configuration key
    # @param value [Object] Value to set
    def set(key, value)
      load! unless @loaded
      
      keys = key.split('.')
      last_key = keys.pop.to_sym
      
      target = keys.reduce(@config_data) do |hash, k|
        hash[k.to_sym] ||= {}
      end
      
      target[last_key] = value
    end

    # Get adapter-specific configuration
    # @param adapter_type [Symbol] Adapter type (e.g., :iris, :yottadb)
    # @return [Hash] Adapter configuration
    def adapter_config(adapter_type)
      load! unless @loaded
      get("adapters.#{adapter_type}", {})
    end

    # Get global FileBot configuration
    # @return [Hash] Global configuration
    def filebot_config
      load! unless @loaded
      {
        default_adapter: get("filebot.default_adapter", :auto_detect),
        performance_logging: get("filebot.performance_logging", true),
        healthcare_audit_enabled: get("filebot.healthcare_audit_enabled", true),
        connection_pool_size: get("filebot.connection_pool_size", 5),
        connection_timeout: get("filebot.connection_timeout", 30),
        debug: get("filebot.debug", false)
      }
    end

    # Check if configuration is valid
    # @return [Boolean] True if valid
    def valid?
      begin
        validate_config!
        true
      rescue => e
        puts "Configuration validation failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        false
      end
    end

    # Get all configuration as hash
    # @return [Hash] Complete configuration
    def to_hash
      load! unless @loaded
      @config_data.dup
    end

    # Reload configuration from sources
    def reload!
      @loaded = false
      load!
    end

    private

    def default_sources
      [
        { type: :environment, prefix: "FILEBOT" },
        { type: :environment, prefix: "IRIS" },
        { type: :environment, prefix: "YOTTADB" },
        { type: :environment, prefix: "GTM" },
        { type: :file, path: File.expand_path("~/.filebot/config.yml") },
        { type: :file, path: "filebot.yml" },
        { type: :file, path: "config/filebot.yml" }
      ]
    end

    def load_source(source)
      case source[:type]
      when :environment
        load_environment_config(source[:prefix])
      when :file
        load_file_config(source[:path])
      when :hash
        source[:data]
      else
        puts "Unknown configuration source type: #{source[:type]}" if ENV['FILEBOT_DEBUG']
        {}
      end
    rescue => e
      puts "Failed to load configuration from #{source}: #{e.message}" if ENV['FILEBOT_DEBUG']
      {}
    end

    def load_environment_config(prefix)
      config = {}
      
      ENV.each do |key, value|
        next unless key.start_with?("#{prefix}_")
        
        # Convert FILEBOT_IRIS_HOST to [:filebot, :iris, :host]
        config_key = key.sub("#{prefix}_", "").downcase.split("_")
        
        # Map adapter-specific vars to adapter config
        if prefix != "FILEBOT"
          config_key = ["adapters", prefix.downcase] + config_key
        else
          config_key = ["filebot"] + config_key
        end
        
        # Set nested value
        target = config
        config_key[0..-2].each do |k|
          target[k.to_sym] ||= {}
          target = target[k.to_sym]
        end
        target[config_key.last.to_sym] = parse_env_value(value)
      end
      
      config
    end

    def load_file_config(path)
      return {} unless File.exist?(path)
      
      case File.extname(path).downcase
      when '.yml', '.yaml'
        require 'yaml'
        YAML.load_file(path)&.transform_keys(&:to_sym) || {}
      when '.json'
        require 'json'
        JSON.parse(File.read(path), symbolize_names: true)
      else
        puts "Unsupported config file format: #{path}" if ENV['FILEBOT_DEBUG']
        {}
      end
    end

    def parse_env_value(value)
      # Parse common environment variable formats
      case value.downcase
      when 'true'
        true
      when 'false'
        false
      when /^\d+$/
        value.to_i
      when /^\d+\.\d+$/
        value.to_f
      else
        value
      end
    end

    def deep_merge(hash1, hash2)
      result = hash1.dup
      
      hash2.each do |key, value|
        if result[key].is_a?(Hash) && value.is_a?(Hash)
          result[key] = deep_merge(result[key], value)
        else
          result[key] = value
        end
      end
      
      result
    end

    def validate_config!
      # Validate global configuration
      default_adapter = get("filebot.default_adapter")
      unless default_adapter.nil? || default_adapter.is_a?(Symbol) || default_adapter.is_a?(String)
        raise "Invalid default_adapter type: #{default_adapter.class}"
      end

      # Validate adapter configurations
      adapters = get("adapters", {})
      adapters.each do |adapter_name, adapter_config|
        validate_adapter_config!(adapter_name, adapter_config)
      end
    end

    def validate_adapter_config!(adapter_name, config)
      return unless config.is_a?(Hash)
      
      # Common validation for all adapters
      if config[:host] && !config[:host].is_a?(String)
        raise "Invalid host for #{adapter_name}: must be string"
      end
      
      if config[:port] && !config[:port].is_a?(Integer)
        raise "Invalid port for #{adapter_name}: must be integer"
      end
      
      # Adapter-specific validation
      case adapter_name.to_sym
      when :iris
        validate_iris_config!(config)
      when :yottadb
        validate_yottadb_config!(config)
      when :gtm
        validate_gtm_config!(config)
      end
    end

    def validate_iris_config!(config)
      required = [:host, :port, :namespace, :username, :password]
      missing = required.select { |key| config[key].nil? || config[key].to_s.empty? }
      
      unless missing.empty?
        puts "Warning: IRIS configuration missing: #{missing.join(', ')}" if ENV['FILEBOT_DEBUG']
      end
    end

    def validate_yottadb_config!(config)
      # YottaDB-specific validation would go here
    end

    def validate_gtm_config!(config)
      # GT.M-specific validation would go here
    end
  end

  # Global configuration instance
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Configure FileBot
  def self.configure
    yield(configuration) if block_given?
    configuration.load!
  end

  # Quick access to configuration values
  def self.config
    configuration.load!
  end
end