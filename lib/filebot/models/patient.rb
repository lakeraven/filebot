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
    end
  end
end