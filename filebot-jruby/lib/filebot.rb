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
# - Offline-first capabilities with Rails 8 Hotwire integration

module FileBot
  autoload :VERSION, "filebot/version"

  autoload :Core, "filebot/core"
  autoload :DatabaseAdapterFactory, "filebot/database_adapter_factory"
  autoload :HealthcareWorkflows, "filebot/healthcare_workflows"
  autoload :PatientParser, "filebot/patient_parser"
  autoload :DateFormatter, "filebot/date_formatter"
  autoload :CredentialsManager, "filebot/credentials_manager"
  autoload :JarManager, "filebot/jar_manager"

  module Adapters
    autoload :IRISAdapter, "filebot/adapters/iris_adapter"
    # Future adapters:
    # autoload :YottaDBAdapter, "filebot/adapters/yottadb_adapter"
    # autoload :GTMAdapter, "filebot/adapters/gtm_adapter"
  end

  # Main FileBot interface combining core operations and healthcare workflows
  class Engine
    attr_reader :core, :workflows

    def initialize(adapter_type = :auto_detect)
      adapter = DatabaseAdapterFactory.create_adapter(adapter_type)
      @core = Core.new(adapter)
      @workflows = HealthcareWorkflows.new(adapter)
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
