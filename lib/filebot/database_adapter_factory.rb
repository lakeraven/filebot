# frozen_string_literal: true

module FileBot
  # Factory for creating appropriate database adapters
  class DatabaseAdapterFactory
    def self.create_adapter(type = :auto_detect)
      case type
      when :iris
        Adapters::IRISAdapter.new
      when :yottadb
        Adapters::YottaDBAdapter.new
      when :gtm
        Adapters::GTMAdapter.new
      when :auto_detect
        auto_detect_adapter
      else
        raise ArgumentError, "Unknown adapter type: #{type}"
      end
    end

    private

    def self.auto_detect_adapter
      # Try IRIS first (most common in healthcare)
      if iris_available?
        puts "FileBot: Auto-detected IRIS database" if ENV['FILEBOT_DEBUG']
        Adapters::IRISAdapter.new
      elsif yottadb_available?
        puts "FileBot: Auto-detected YottaDB" if ENV['FILEBOT_DEBUG']
        Adapters::YottaDBAdapter.new
      elsif gtm_available?
        puts "FileBot: Auto-detected GT.M" if ENV['FILEBOT_DEBUG']
        Adapters::GTMAdapter.new
      else
        raise "FileBot: No supported MUMPS database detected"
      end
    end

    def self.iris_available?
      # Check for IRIS JDBC driver
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

    def self.yottadb_available?
      # Check for YottaDB installation
      system("which ydb > /dev/null 2>&1") ||
      File.exist?("/usr/local/lib/yottadb") ||
      !ENV["ydb_dir"].nil?
    end

    def self.gtm_available?
      # Check for GT.M installation
      system("which gtm > /dev/null 2>&1") ||
      File.exist?("/usr/lib/fis-gtm") ||
      !ENV["gtm_dir"].nil?
    end
  end
end
