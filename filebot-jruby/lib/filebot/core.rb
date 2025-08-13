# frozen_string_literal: true

module FileBot
  # Core FileBot class for high-performance healthcare operations
  # Uses pure Java Native API for direct MUMPS global access
  class Core
    attr_reader :adapter

    def initialize(adapter = nil)
      @adapter = adapter || DatabaseAdapterFactory.create_adapter
    end

    # Ultra-fast patient lookup using pure Java Native API
    def get_patient_demographics(dfn)
      begin
        result = @adapter.get_global("^DPT", dfn.to_s, "0")
        return nil if result.nil? || result.empty?

        PatientParser.parse_zero_node(dfn, result)
      rescue => e
        Rails.logger.error "FileBot: Native patient lookup failed: #{e.message}"
        nil
      end
    end

    # Ultra-fast patient search using direct B cross-reference
    def search_patients_by_name(name_pattern)
      begin
        patients = []
        search_name = name_pattern.upcase

        # Direct cross-reference traversal
        current_name = @adapter.order_global("^DPT", "B", search_name)

        while current_name && current_name.start_with?(search_name) && patients.length < 10
          dfn_str = @adapter.order_global("^DPT", "B", current_name, "")

          if dfn_str && !dfn_str.empty?
            dfn = dfn_str.to_i
            if dfn > 0
              data = @adapter.get_global("^DPT", dfn.to_s, "0")

              if data && !data.empty?
                patients << PatientParser.parse_zero_node(dfn, data)
              end
            end
          end

          current_name = @adapter.order_global("^DPT", "B", current_name)
        end

        patients.compact
      rescue => e
        Rails.logger.error "FileBot: Native search failed: #{e.message}"
        []
      end
    end

    # Ultra-fast patient creation using direct global sets
    def create_patient(patient_data)
      begin
        dfn = get_next_dfn

        # Build patient record
        name = patient_data[:name]
        ssn = patient_data[:ssn]
        dob = DateFormatter.format_for_fileman(patient_data[:dob])
        sex = patient_data[:sex]
        patient_record = "#{name}^#{ssn}^#{dob}^#{sex}"

        # Direct global sets
        @adapter.set_global(patient_record, "^DPT", dfn.to_s, "0")

        # Set cross-references
        @adapter.set_global("", "^DPT", "B", name, dfn.to_s)
        @adapter.set_global("", "^DPT", "SSN", ssn, dfn.to_s)

        # Update file header
        @adapter.set_global(dfn.to_s, "^DPT", "0")

        { success: true, dfn: dfn }
      rescue => e
        Rails.logger.error "FileBot: Native patient creation failed: #{e.message}"
        { success: false, error: e.message }
      end
    end

    # Ultra-fast batch patient retrieval
    def get_patients_batch(dfn_list)
      begin
        return [] if dfn_list.empty?

        patients = []

        dfn_list.each do |dfn|
          data = @adapter.get_global("^DPT", dfn.to_s, "0")

          if data && !data.empty?
            patients << PatientParser.parse_zero_node(dfn, data)
          end
        end

        patients.compact
      rescue => e
        Rails.logger.error "FileBot: Native batch retrieval failed: #{e.message}"
        []
      end
    end

    # Ultra-fast clinical summary using direct global access
    def get_patient_clinical_summary(dfn)
      begin
        # Get patient demographics
        demo_data = @adapter.get_global("^DPT", dfn.to_s, "0") || ""

        # Get allergies - traverse cross-reference
        allergies = []
        allergy_ien = @adapter.order_global("^GMR", "120.8", "B", dfn.to_s, "")

        while allergy_ien && !allergy_ien.empty? && allergies.length < 20
          allergy_data = @adapter.get_global("^GMR", "120.8", allergy_ien, "0")

          if allergy_data && !allergy_data.empty?
            pieces = allergy_data.split("^")
            allergen = pieces[1] if pieces.length > 1
            allergies << allergen if allergen && !allergen.empty?
          end

          allergy_ien = @adapter.order_global("^GMR", "120.8", "B", dfn.to_s, allergy_ien)
        end

        # Get latest visit
        latest_visit = ""
        visit_id = @adapter.order_global("^AUPNVSIT", "B", dfn.to_s, "", -1)

        if visit_id && !visit_id.empty?
          latest_visit = @adapter.get_global("^AUPNVSIT", visit_id, "0") || ""
        end

        # Combine results
        combined_result = "#{demo_data}~~#{allergies.join('~')}~~#{latest_visit}"
        PatientParser.parse_clinical_summary(dfn, combined_result)
      rescue => e
        Rails.logger.error "FileBot: Native clinical summary failed: #{e.message}"
        nil
      end
    end

    # Ultra-fast validation using direct global checks
    def validate_patient(patient_data)
      errors = []

      # Client-side validation for speed
      errors << "Name required" if patient_data[:name].blank?
      errors << "Invalid SSN format" if patient_data[:ssn]&.match?(/^0{3,}/)
      errors << "Sex must be M or F" if !%w[M F].include?(patient_data[:sex])
      errors << "DOB required" if patient_data[:dob].nil?

      # Only check database for uniqueness if basic validation passes
      if errors.empty? && patient_data[:ssn].present?
        begin
          exists = @adapter.data_global("^DPT", "SSN", patient_data[:ssn])
          errors << "SSN already exists" if exists && exists > 0
        rescue => e
          Rails.logger.error "FileBot: Native validation check failed: #{e.message}"
          errors << "Validation check failed"
        end
      end

      { success: errors.empty?, errors: errors }
    end

    private

    def get_next_dfn
      current = @adapter.get_global("^DPT", "0") || "0"
      current.to_i + 1
    end
  end
end
