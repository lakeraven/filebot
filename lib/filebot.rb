# frozen_string_literal: true

# FileBot - High-Performance Healthcare MUMPS Modernization Platform
#
# Provides 6.96x performance improvement over Legacy FileMan while maintaining
# full MUMPS/VistA compatibility and enabling modern healthcare workflows.
#
# Features:
# - Pure Java Native API for direct MUMPS global access
# - Healthcare-specific workflow optimizations
# - FHIR R4 serialization capabilities
# - Multi-platform MUMPS database support (IRIS, YottaDB, GT.M)
# - Event sourcing compatible architecture
# - Offline-first capabilities with modern web framework integration

module FileBot
  autoload :VERSION, "filebot/version"

  # Core components
  autoload :Core, "filebot/core"
  autoload :Configuration, "filebot/configuration"
  autoload :AdapterRegistry, "filebot/adapter_registry"
  autoload :DatabaseAdapterFactory, "filebot/database_adapter_factory"
  
  # Healthcare and utilities
  autoload :HealthcareWorkflows, "filebot/healthcare_workflows"
  autoload :PatientParser, "filebot/patient_parser"
  autoload :DateFormatter, "filebot/date_formatter"
  autoload :CredentialsManager, "filebot/credentials_manager"
  autoload :JarManager, "filebot/jar_manager"

  # Adapter ecosystem
  module Adapters
    autoload :BaseAdapter, "filebot/adapters/base_adapter"
    autoload :IRISAdapter, "filebot/adapters/iris_adapter"
    autoload :YottaDBAdapter, "filebot/adapters/yottadb_adapter"
    autoload :GTMAdapter, "filebot/adapters/gtm_adapter"
  end

  # Main FileBot interface combining core operations and healthcare workflows
  # Now implementation-agnostic with pluggable adapter architecture
  class Engine
    attr_reader :core, :workflows, :adapter

    def initialize(adapter_type = :auto_detect, config = {})
      # Create adapter with configuration support
      @adapter = if adapter_type.is_a?(Symbol)
        DatabaseAdapterFactory.create_adapter(adapter_type, config)
      else
        adapter_type  # Assume it's already an adapter instance
      end
      
      @core = Core.new(@adapter, config)
      @workflows = HealthcareWorkflows.new(@adapter)
    end

    # === Adapter Management ===

    def adapter_info
      @core.adapter_info
    end

    def switch_adapter!(new_adapter_type, config = {})
      @core.switch_adapter!(new_adapter_type, config)
      @workflows = HealthcareWorkflows.new(@core.adapter)
    end

    def test_connection
      @core.test_connection
    end

    # Delegate core operations
    def get_patient_demographics(dfn)
      @core.get_patient_demographics(dfn)
    end

    def search_patients_by_name(name_pattern)
      @core.search_patients_by_name(name_pattern)
    end

    def create_patient(patient_data)
      @core.create_patient(patient_data)
    end

    def get_patients_batch(dfn_list)
      @core.get_patients_batch(dfn_list)
    end

    def get_patient_clinical_summary(dfn)
      @core.get_patient_clinical_summary(dfn)
    end

    def validate_patient(patient_data)
      @core.validate_patient(patient_data)
    end

    # Delegate core database operations
    def find_entries(file_number, search_value, search_field = nil, flags = nil, max_results = 10)
      @core.find_entries(file_number, search_value, search_field, flags, max_results)
    end

    def list_entries(file_number, start_from = "", fields = ".01", max_results = 20, screen = nil)
      @core.list_entries(file_number, start_from, fields, max_results, screen)
    end

    def delete_entry(file_number, ien)
      @core.delete_entry(file_number, ien)
    end

    def lock_entry(file_number, ien, timeout = 30)
      @core.lock_entry(file_number, ien, timeout)
    end

    def unlock_entry(file_number, ien)
      @core.unlock_entry(file_number, ien)
    end

    def gets_entry(file_number, ien, fields, flags = "EI")
      @core.gets_entry(file_number, ien, fields, flags)
    end

    def update_entry(file_number, ien, field_data)
      @core.update_entry(file_number, ien, field_data)
    end

    # Delegate healthcare workflows
    def medication_ordering_workflow(dfn)
      @workflows.medication_ordering_workflow(dfn)
    end

    def lab_result_entry_workflow(dfn, test_name, result)
      @workflows.lab_result_entry_workflow(dfn, test_name, result)
    end

    def clinical_documentation_workflow(dfn, note_type, content)
      @workflows.clinical_documentation_workflow(dfn, note_type, content)
    end

    def discharge_summary_workflow(dfn)
      @workflows.discharge_summary_workflow(dfn)
    end
  end

  # Convenience method for creating FileBot instances
  def self.new(adapter_type = :auto_detect)
    Engine.new(adapter_type)
  end
end
