# frozen_string_literal: true

module FileBot
  # Manages MUMPS database JAR files for different platforms
  class JarManager
    class << self
      # Find and load IRIS JAR files
      def load_iris_jars!
        binding_jar = find_iris_jar("binding")
        jdbc_jar = find_iris_jar("jdbc")

        add_to_classpath(binding_jar, "IRIS binding")
        add_to_classpath(jdbc_jar, "IRIS JDBC")

      end

      # Find and load YottaDB JAR files (future implementation)
      def load_yottadb_jars!
        # YottaDB doesn't have Java JAR dependencies
      end

      # Find and load GT.M JAR files (future implementation)
      def load_gtm_jars!
        # GT.M doesn't have standard Java JAR dependencies
      end

      private

      def find_iris_jar(jar_type)
        search_paths = iris_search_paths
        jar = find_jar_in_paths(search_paths, "intersystems", jar_type)

        unless jar
          raise JarNotFoundError, "InterSystems #{jar_type} JAR not found. Searched: #{search_paths.join(', ')}"
        end

        jar
      end

      def iris_search_paths
        @iris_search_paths ||= [
          # Application directories
          File.join(Dir.pwd, "lib", "jars"),
          File.join(Dir.pwd, "vendor", "jars"),
          File.join(Dir.pwd, "vendor", "java"),

          # Environment-specific paths
          ENV["INTERSYSTEMS_HOME"],
          ENV["IRIS_HOME"],
          ENV["CACHE_HOME"],

          # Standard system paths
          "/usr/local/lib/intersystems",
          "/opt/intersystems",
          "/usr/share/java/intersystems",

          # Container/Docker paths
          "/app/lib/jars",
          "/app/vendor/jars",

          # Maven local repository
          "#{ENV['HOME']}/.m2/repository/com/intersystems",

          # Gradle cache
          "#{ENV['HOME']}/.gradle/caches/**/intersystems",

          # Current working directory (development)
          Dir.pwd
        ].compact.map(&:to_s)
      end

      def find_jar_in_paths(search_paths, vendor, jar_type)
        search_paths.each do |base_path|
          next unless Dir.exist?(base_path)

          # Search recursively for JAR files
          pattern = File.join(base_path, "**", "*#{vendor}*#{jar_type}*.jar")
          jars = Dir.glob(pattern, File::FNM_CASEFOLD)

          # Return first match
          return jars.first unless jars.empty?
        end

        nil
      end

      def add_to_classpath(jar_path, description)
        return if jar_path.nil?

        unless File.exist?(jar_path)
          raise JarNotFoundError, "#{description} JAR file does not exist: #{jar_path}"
        end

        # Add to JRuby classpath
        $CLASSPATH << jar_path
      end
    end

    # Custom exception for JAR not found errors
    class JarNotFoundError < StandardError; end
  end
end
