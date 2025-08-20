# frozen_string_literal: true

require 'date'
require_relative '../date_formatter'

module FileBot
  module Models
    # Patient domain model - replaces MUMPS FileMan business logic
    class Patient
      attr_reader :dfn, :name, :ssn, :dob, :sex, :adapter
      
      def initialize(dfn, adapter, data = nil)
        @dfn = dfn.to_s
        @adapter = adapter
        load_data(data) if data
      end
      
      # Load patient from database (replaces FileMan GETS^DIQ)
      def self.find(dfn, adapter)
        data = adapter.get_global("^DPT", dfn.to_s, "0")
        return nil if data.nil? || data.empty?
        
        patient = new(dfn, adapter)
        patient.send(:load_data, data)
        patient
      end
      
      # Create new patient (replaces FileMan FILE^DIE)
      def self.create(attributes, adapter)
        # Generate new DFN
        dfn = generate_new_dfn(adapter)
        
        # Validate required fields
        validate_patient_attributes!(attributes)
        
        # Format data for storage
        formatted_data = format_patient_data(attributes)
        
        # Store to database
        adapter.set_global("^DPT", dfn, "0", formatted_data)
        
        # Return patient instance
        patient = new(dfn, adapter)
        patient.send(:load_data, formatted_data)
        patient
      end
      
      # Update patient data
      def update(attributes)
        validate_patient_attributes!(attributes)
        
        # Merge with existing data
        current_data = {
          name: @name,
          ssn: @ssn, 
          dob: @dob,
          sex: @sex
        }.merge(attributes)
        
        formatted_data = self.class.format_patient_data(current_data)
        @adapter.set_global("^DPT", @dfn, "0", formatted_data)
        
        load_data(formatted_data)
        self
      end
      
      # Patient search (replaces FileMan FIND^DIC)
      def self.search_by_name(name_pattern, adapter, limit = 50)
        results = []
        pattern = name_pattern.upcase
        
        # Traverse the B index for name lookup
        # This replaces MUMPS FileMan B cross-reference traversal
        key = ""
        count = 0
        
        while count < limit
          key = adapter.order_global("^DPT", "B", key)
          break if key.nil? || key.empty?
          
          if key.start_with?(pattern)
            # Get the DFN(s) for this name
            dfn = adapter.order_global("^DPT", "B", key, "")
            if dfn && !dfn.empty?
              patient = find(dfn, adapter)
              results << patient if patient
              count += 1
            end
          elsif key > pattern + "~" # Alphabetically past our search
            break
          end
        end
        
        results
      end
      
      # Get patient allergies
      def allergies
        @allergies ||= load_allergies
      end
      
      # Get patient medications  
      def medications
        @medications ||= load_medications
      end
      
      # Healthcare workflow: clinical summary
      def clinical_summary
        {
          demographics: {
            dfn: @dfn,
            name: @name,
            ssn: @ssn,
            dob: @dob,
            sex: @sex
          },
          allergies: allergies,
          medications: medications,
          last_visit: load_last_visit
        }
      end
      
      # Priority 1: Delete patient record (replaces FileMan EN^DIEZ)
      def self.delete(dfn, adapter)
        begin
          # Find patient first to get cross-reference data
          patient = find(dfn, adapter)
          return { success: false, error: "Patient not found" } unless patient
          
          # Remove main record
          adapter.set_global("^DPT", dfn, "0", "")
          
          # Clean up B cross-reference
          if patient.name && !patient.name.empty?
            adapter.set_global("^DPT", "B", patient.name.upcase, dfn, "")
          end
          
          { success: true, dfn: dfn, deleted: true }
        rescue => e
          { success: false, error: e.message }
        end
      end
      
      # Priority 1: Advanced search with Boolean logic
      def self.boolean_search(criteria, adapter, limit = 50)
        results = []
        
        # Support AND/OR operations
        if criteria[:and]
          results = search_with_and_logic(criteria[:and], adapter, limit)
        elsif criteria[:or]
          results = search_with_or_logic(criteria[:or], adapter, limit)
        else
          # Simple criteria search
          results = search_by_criteria(criteria, adapter, limit)
        end
        
        results
      end
      
      # Priority 1: Range search operations
      def self.range_search(field, range_criteria, adapter, limit = 50)
        results = []
        
        case field
        when :dob
          results = search_by_date_range(range_criteria, adapter, limit)
        when :dfn
          results = search_by_dfn_range(range_criteria, adapter, limit)
        when :name
          results = search_by_name_range(range_criteria, adapter, limit)
        end
        
        results
      end
      
      # Priority 1: Multiple field processing
      def update_multiple_fields(field_updates, adapter)
        begin
          # Validate all fields first
          field_updates.each do |field, value|
            validate_field_update(field, value)
          end
          
          # Apply all updates atomically
          current_data = {
            name: @name,
            ssn: @ssn,
            dob: @dob,
            sex: @sex
          }.merge(field_updates)
          
          formatted_data = self.class.format_patient_data(current_data)
          @adapter.set_global("^DPT", @dfn, "0", formatted_data)
          
          # Update cross-references if name changed
          if field_updates[:name]
            @adapter.set_global("^DPT", "B", field_updates[:name].upcase, @dfn, "")
          end
          
          load_data(formatted_data)
          { success: true, updated_fields: field_updates.keys }
        rescue => e
          { success: false, error: e.message }
        end
      end
      
      # Priority 1: Cross-reference rebuilding
      def self.rebuild_cross_references(dfn, adapter)
        begin
          patient = find(dfn, adapter)
          return { success: false, error: "Patient not found" } unless patient
          
          # Rebuild B (name) cross-reference
          if patient.name && !patient.name.empty?
            adapter.set_global("^DPT", "B", patient.name.upcase, dfn, "")
          end
          
          # Rebuild C (SSN) cross-reference
          if patient.ssn && !patient.ssn.empty?
            adapter.set_global("^DPT", "C", patient.ssn, dfn, "")
          end
          
          { success: true, dfn: dfn, cross_references_rebuilt: ["B", "C"] }
        rescue => e
          { success: false, error: e.message }
        end
      end
      
      # Validation rules (replaces FileMan input transforms and validations)
      def self.validate_patient_attributes!(attributes)
        raise ArgumentError, "Name is required" if attributes[:name].nil? || attributes[:name].strip.empty?
        raise ArgumentError, "Invalid SSN format" if attributes[:ssn] && !valid_ssn?(attributes[:ssn])
        raise ArgumentError, "Invalid sex" if attributes[:sex] && !%w[M F].include?(attributes[:sex])
        raise ArgumentError, "Invalid date of birth" if attributes[:dob] && !valid_date?(attributes[:dob])
      end
      
      private
      
      def load_data(data)
        fields = data.split("^")
        @name = fields[0]
        @ssn = fields[1] 
        @dob = DateFormatter.parse_fileman_date(fields[2])
        @sex = fields[3]
      end
      
      def self.format_patient_data(attributes)
        dob_formatted = attributes[:dob].is_a?(Date) ? 
          DateFormatter.format_for_fileman(attributes[:dob]) : 
          attributes[:dob].to_s
          
        [
          attributes[:name],
          attributes[:ssn],
          dob_formatted,
          attributes[:sex]
        ].join("^")
      end
      
      def self.generate_new_dfn(adapter)
        # Generate new DFN using timestamp-based approach for testing
        # In production, this would use proper FileMan DFN allocation
        base_dfn = 50000 # Use high numbers to avoid conflicts
        random_increment = rand(1000..9999)
        (base_dfn + random_increment).to_s
      end
      
      def load_allergies
        # Load from ^GMR(120.8) allergy file
        allergy_data = []
        key = @adapter.order_global("^GMR", "120.8", "B", @dfn, "")
        
        while key && !key.empty?
          data = @adapter.get_global("^GMR", "120.8", key, "0")
          allergy_data << parse_allergy(data) if data && !data.empty?
          key = @adapter.order_global("^GMR", "120.8", "B", @dfn, key)
        end
        
        allergy_data
      end
      
      def load_medications
        # Load from ^PS(55) medication file  
        med_data = []
        med_ien = @adapter.order_global("^PS", "55", @dfn, "5", "")
        
        while med_ien && !med_ien.empty?
          data = @adapter.get_global("^PS", "55", @dfn, "5", med_ien, "0")
          med_data << parse_medication(data) if data && !data.empty?
          med_ien = @adapter.order_global("^PS", "55", @dfn, "5", med_ien)
        end
        
        med_data
      end
      
      def load_last_visit
        # Load most recent visit from ^AUPNVSIT
        visit_data = @adapter.get_global("^AUPNVSIT", "B", @dfn)
        return nil unless visit_data
        
        parse_visit(visit_data)
      end
      
      def parse_allergy(data)
        fields = data.split("^")
        {
          allergen: fields[0],
          severity: fields[1],
          date_entered: DateFormatter.parse_fileman_date(fields[2])
        }
      end
      
      def parse_medication(data)
        fields = data.split("^")
        {
          drug_name: fields[0],
          dosage: fields[1],
          start_date: DateFormatter.parse_fileman_date(fields[2]),
          status: fields[3]
        }
      end
      
      def parse_visit(data)
        fields = data.split("^")
        {
          date: DateFormatter.parse_fileman_date(fields[0]),
          location: fields[1],
          provider: fields[2]
        }
      end
      
      def self.valid_ssn?(ssn)
        ssn.to_s.match?(/^\d{9}$/)
      end
      
      def self.valid_date?(date)
        return true if date.is_a?(Date)
        return false unless date.is_a?(String) && date.length == 7
        DateFormatter.parse_fileman_date(date) != nil
      end
      
      # Priority 1: Supporting methods for advanced search
      def self.search_with_and_logic(criteria_list, adapter, limit)
        # Start with all patients, then filter down
        all_results = search_by_name("", adapter, 1000)  # Get larger set first
        
        criteria_list.each do |criteria|
          all_results = all_results.select do |patient|
            matches_criteria?(patient, criteria)
          end
        end
        
        all_results.first(limit)
      end
      
      def self.search_with_or_logic(criteria_list, adapter, limit)
        all_results = []
        
        criteria_list.each do |criteria|
          results = search_by_criteria(criteria, adapter, limit)
          all_results.concat(results)
        end
        
        # Remove duplicates and limit
        all_results.uniq { |p| p.dfn }.first(limit)
      end
      
      def self.search_by_criteria(criteria, adapter, limit)
        if criteria[:name]
          search_by_name(criteria[:name], adapter, limit)
        elsif criteria[:ssn]
          search_by_ssn(criteria[:ssn], adapter, limit)
        elsif criteria[:sex]
          search_by_sex(criteria[:sex], adapter, limit)
        else
          []
        end
      end
      
      def self.search_by_ssn(ssn_pattern, adapter, limit)
        # Would implement SSN cross-reference search
        # For now, simulate by searching through records
        search_by_name("", adapter, 1000).select do |patient|
          patient.ssn && patient.ssn.include?(ssn_pattern)
        end.first(limit)
      end
      
      def self.search_by_sex(sex, adapter, limit)
        # Search through records for sex match
        search_by_name("", adapter, 1000).select do |patient|
          patient.sex == sex
        end.first(limit)
      end
      
      def self.search_by_date_range(range_criteria, adapter, limit)
        start_date = range_criteria[:start]
        end_date = range_criteria[:end]
        
        search_by_name("", adapter, 1000).select do |patient|
          patient.dob && 
          patient.dob >= start_date && 
          patient.dob <= end_date
        end.first(limit)
      end
      
      def self.search_by_dfn_range(range_criteria, adapter, limit)
        start_dfn = range_criteria[:start].to_i
        end_dfn = range_criteria[:end].to_i
        
        search_by_name("", adapter, 1000).select do |patient|
          dfn_num = patient.dfn.to_i
          dfn_num >= start_dfn && dfn_num <= end_dfn
        end.first(limit)
      end
      
      def self.search_by_name_range(range_criteria, adapter, limit)
        start_name = range_criteria[:start].upcase
        end_name = range_criteria[:end].upcase
        
        search_by_name("", adapter, 1000).select do |patient|
          patient.name &&
          patient.name.upcase >= start_name &&
          patient.name.upcase <= end_name
        end.first(limit)
      end
      
      def self.matches_criteria?(patient, criteria)
        criteria.all? do |field, value|
          case field
          when :name
            patient.name && patient.name.upcase.include?(value.upcase)
          when :ssn
            patient.ssn && patient.ssn.include?(value)
          when :sex
            patient.sex == value
          when :dob
            patient.dob == value
          else
            false
          end
        end
      end
      
      def validate_field_update(field, value)
        case field
        when :name
          raise ArgumentError, "Name cannot be empty" if value.nil? || value.strip.empty?
        when :ssn
          raise ArgumentError, "Invalid SSN format" unless self.class.valid_ssn?(value)
        when :sex
          raise ArgumentError, "Invalid sex" unless %w[M F].include?(value)
        when :dob
          raise ArgumentError, "Invalid date" unless value.is_a?(Date)
        end
      end
    end
  end
end