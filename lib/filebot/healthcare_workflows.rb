# frozen_string_literal: true

module FileBot
  # Healthcare-specific workflow implementations
  class HealthcareWorkflows
    def initialize(adapter)
      @adapter = adapter
    end

    # Healthcare Workflow: Medication Ordering
    def medication_ordering_workflow(dfn)
      begin
        # Pure Native API global access
        patient_data = @adapter.get_global("^DPT", dfn.to_s, "0") || ""

        # Get patient allergies - traverse cross-reference
        allergy_ien = @adapter.order_global("^GMR", "120.8", "B", dfn.to_s, "")
        allergy_data = ""
        if allergy_ien && !allergy_ien.empty?
          allergy_data = @adapter.get_global("^GMR", "120.8", allergy_ien, "0") || ""
        end

        # Get current medications - traverse medication file
        med_ien = @adapter.order_global("^PS", "55", dfn.to_s, "5", "")
        medication_data = ""
        if med_ien && !med_ien.empty?
          medication_data = @adapter.get_global("^PS", "55", dfn.to_s, "5", med_ien, "0") || ""
        end

        {
          success: true,
          workflow: "medication_ordering",
          patient: patient_data,
          allergies: allergy_data,
          medications: medication_data
        }
      rescue => e
        { success: false, error: e.message }
      end
    end

    # Healthcare Workflow: Lab Result Entry
    def lab_result_entry_workflow(dfn, test_name, result)
      begin
        # Get patient context with pure native API
        patient_data = @adapter.get_global("^DPT", dfn.to_s, "0") || ""

        # Create lab entry with native global set
        lab_ien = rand(1000..9999).to_s
        lab_record = "#{test_name}^#{result}^#{Date.current.strftime('%Y%m%d')}"
        @adapter.set_global(lab_record, "^LAB", "60", dfn.to_s, lab_ien, "0")

        # Set cross-reference for lab lookup
        @adapter.set_global("", "^LAB", "60", "B", test_name, dfn.to_s, lab_ien)

        { success: true, lab_ien: lab_ien, patient: patient_data }
      rescue => e
        { success: false, error: e.message }
      end
    end

    # Healthcare Workflow: Clinical Documentation
    def clinical_documentation_workflow(dfn, note_type, content)
      begin
        # Get patient context with pure native API
        patient_data = @adapter.get_global("^DPT", dfn.to_s, "0") || ""

        # Create clinical note with native global operations
        note_ien = rand(10000..99999).to_s
        timestamp = Time.current.strftime("%Y%m%d%H%M%S")
        note_record = "#{note_type}^#{dfn}^#{timestamp}^#{content[0..50] if content}"
        @adapter.set_global(note_record, "^TIU", "8925", note_ien, "0")

        # Set patient cross-reference
        @adapter.set_global("", "^TIU", "8925", "B", dfn.to_s, note_ien)

        { success: true, note_ien: note_ien, patient: patient_data }
      rescue => e
        { success: false, error: e.message }
      end
    end

    # Healthcare Workflow: Discharge Summary
    def discharge_summary_workflow(dfn)
      begin
        # Get all discharge summary data with pure native API
        patient_data = @adapter.get_global("^DPT", dfn.to_s, "0") || ""

        # Get allergies
        allergy_ien = @adapter.order_global("^GMR", "120.8", "B", dfn.to_s, "")
        allergy_data = ""
        if allergy_ien && !allergy_ien.empty?
          allergy_data = @adapter.get_global("^GMR", "120.8", allergy_ien, "0") || ""
        end

        # Get medications
        med_ien = @adapter.order_global("^PS", "55", dfn.to_s, "5", "")
        medication_data = ""
        if med_ien && !med_ien.empty?
          medication_data = @adapter.get_global("^PS", "55", dfn.to_s, "5", med_ien, "0") || ""
        end

        # Get latest visit
        latest_visit_ien = @adapter.order_global("^AUPNVSIT", "B", dfn.to_s, "", -1)
        visit_data = ""
        if latest_visit_ien && !latest_visit_ien.empty?
          visit_data = @adapter.get_global("^AUPNVSIT", latest_visit_ien, "0") || ""
        end

        summary_data = {
          patient: patient_data,
          allergies: allergy_data,
          medications: medication_data,
          last_visit: visit_data
        }

        { success: true, summary: summary_data }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
