# frozen_string_literal: true

# FileBot vs Legacy RPMS Benchmark Configuration
module BenchmarkConfig
  # Test configuration
  DEFAULT_ITERATIONS = 100
  BATCH_SIZE = 20
  CONCURRENT_THREADS = 10
  CONCURRENT_OPERATIONS_PER_THREAD = 10
  
  # Performance expectations (in seconds)
  PERFORMANCE_TARGETS = {
    patient_creation: {
      legacy_expected: 0.008,    # 8ms per operation (legacy FileMan overhead)
      filebot_target: 0.003,     # 3ms per operation (target improvement)
      max_acceptable: 0.100      # 100ms maximum acceptable
    },
    patient_retrieval: {
      legacy_expected: 0.005,    # 5ms per operation (legacy GETS^DIQ)
      filebot_target: 0.001,     # 1ms per operation (direct global access)
      max_acceptable: 0.050      # 50ms maximum acceptable
    },
    patient_update: {
      legacy_expected: 0.007,    # 7ms per operation (legacy UPDATE^DIE)
      filebot_target: 0.002,     # 2ms per operation (optimized updates)
      max_acceptable: 0.075      # 75ms maximum acceptable
    },
    validation: {
      legacy_expected: 0.003,    # 3ms per validation (legacy rules)
      filebot_target: 0.001,     # 1ms per validation (modern validators)
      max_acceptable: 0.025      # 25ms maximum acceptable
    },
    cross_references: {
      legacy_expected: 0.004,    # 4ms per cross-ref (legacy indexing)
      filebot_target: 0.001,     # 1ms per cross-ref (IRIS native)
      max_acceptable: 0.050      # 50ms maximum acceptable
    }
  }.freeze
  
  # Healthcare-specific test data patterns
  TEST_PATIENT_TEMPLATES = {
    standard: {
      "0.01" => "LASTNAME,FIRSTNAME",
      "0.02" => "M",
      "0.03" => "1985-05-15",
      "0.09" => "123456789",
      "0.11" => "123 MAIN STREET",
      "0.131" => "555-1234"
    },
    complex: {
      "0.01" => "COMPLEXNAME-HYPHENATED,FIRSTNAME MIDDLE",
      "0.02" => "F", 
      "0.03" => "1965-12-25",
      "0.09" => "987654321",
      "0.11" => "456 COMPLEX ADDRESS UNIT 2B",
      "0.111" => "LONG CITY NAME",
      "0.112" => "CA",
      "0.113" => "90210-1234",
      "0.131" => "555-COMPLEX",
      # Additional fields for complexity
      "veteran_flag" => "Y",
      "service_number" => "123456789",
      "consent_flag" => "Y"
    },
    minimal: {
      "0.01" => "DOE,JANE",
      "0.02" => "F"
    }
  }.freeze
  
  # Validation test cases
  VALIDATION_TEST_CASES = [
    # Valid cases
    { data: { "0.01" => "VALID,PATIENT", "0.09" => "123456789" }, should_pass: true },
    { data: { "0.01" => "ANOTHER,PATIENT", "0.03" => "1985-05-15" }, should_pass: true },
    
    # Invalid cases  
    { data: { "0.01" => "TEST,PATIENT", "0.09" => "123456789" }, should_pass: false }, # Prohibited name
    { data: { "0.01" => "", "0.02" => "M" }, should_pass: false }, # Missing required field
    { data: { "0.01" => "VALID,NAME", "0.02" => "X" }, should_pass: false }, # Invalid gender
    { data: { "0.01" => "VALID,NAME", "0.09" => "000000000" }, should_pass: false }, # Invalid SSN
    { data: { "0.01" => "VALID,NAME", "0.03" => "invalid-date" }, should_pass: false }, # Invalid date
    
    # Complex validation scenarios
    { data: { "0.01" => "ADULT,PATIENT", "0.03" => "1980-01-01", "consent_flag" => "N" }, should_pass: false }, # Adult without consent
    { data: { "veteran_flag" => "Y", "service_number" => "" }, should_pass: false } # Veteran without service number
  ].freeze
  
  # Cross-reference test scenarios
  CROSS_REFERENCE_SCENARIOS = {
    name_index: {
      field: "0.01",
      test_values: ["SMITH,JOHN", "O'CONNOR,MARY", "VAN DER BERG,PETER"]
    },
    ssn_index: {
      field: "0.09", 
      test_values: ["123456789", "987654321", "555443333"]
    },
    soundex_index: {
      field: "0.01",
      test_values: ["SMITH,JOHN", "SMYTH,JOHN", "SCHMIDT,JOHAN"]
    }
  }.freeze
  
  # Benchmark reporting configuration
  REPORT_CONFIG = {
    show_individual_timings: true,
    show_operations_per_second: true,
    show_improvement_ratios: true,
    show_healthcare_analysis: true,
    export_csv: false, # Set to true to export CSV results
    csv_filename: "filebot_benchmark_results.csv"
  }.freeze
  
  # System configuration
  SYSTEM_CONFIG = {
    require_jruby: true,
    require_iris: true,
    warmup_iterations: 10, # Warmup JVM before benchmarking
    gc_between_tests: true, # Force garbage collection between tests
    measure_memory: false   # Memory usage measurement (experimental)
  }.freeze
  
  # Healthcare compliance benchmarks
  COMPLIANCE_BENCHMARKS = {
    hipaa_audit_logging: {
      enabled: true,
      expected_overhead: 0.001 # 1ms overhead for audit logging
    },
    data_validation: {
      enabled: true,
      healthcare_rules: true,
      business_rules: true
    },
    security_checks: {
      enabled: true,
      access_control: true,
      field_level_security: false # Not implemented yet
    }
  }.freeze
  
  def self.get_iterations(test_type = :default)
    case test_type
    when :quick
      25
    when :standard  
      DEFAULT_ITERATIONS
    when :comprehensive
      500
    when :stress
      1000
    else
      DEFAULT_ITERATIONS
    end
  end
  
  def self.get_performance_target(operation, metric)
    PERFORMANCE_TARGETS.dig(operation, metric)
  end
  
  def self.get_test_data(template = :standard)
    TEST_PATIENT_TEMPLATES[template]&.dup
  end
  
  def self.validate_environment
    errors = []
    
    if SYSTEM_CONFIG[:require_jruby] && RUBY_PLATFORM != "java"
      errors << "JRuby required but not detected"
    end
    
    if SYSTEM_CONFIG[:require_iris]
      begin
        java_import "com.intersystems.jdbc.IRISConnection"
      rescue => e
        errors << "IRIS JDBC driver not available: #{e.message}"
      end
    end
    
    errors
  end
  
  def self.benchmark_summary
    {
      iterations: DEFAULT_ITERATIONS,
      batch_size: BATCH_SIZE,
      concurrent_threads: CONCURRENT_THREADS,
      test_templates: TEST_PATIENT_TEMPLATES.keys,
      validation_cases: VALIDATION_TEST_CASES.length,
      cross_ref_scenarios: CROSS_REFERENCE_SCENARIOS.keys,
      compliance_enabled: COMPLIANCE_BENCHMARKS.select { |k, v| v[:enabled] }.keys
    }
  end
end