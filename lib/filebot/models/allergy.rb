# frozen_string_literal: true

require 'date'
require_relative '../date_formatter'

module FileBot
  module Models
    # Priority 3: Healthcare-specific Allergy model - replaces FileMan Adverse Reaction file
    class Allergy
      attr_reader :ien, :patient_dfn, :allergen, :severity, :date_entered, :adapter
      
      def initialize(ien, adapter, data = nil)
        @ien = ien.to_s
        @adapter = adapter
        load_data(data) if data
      end
      
      # Create new allergy record (sub-file operation)
      def self.create(patient_dfn, attributes, adapter)
        # Generate new IEN
        ien = generate_new_ien(adapter)
        
        # Validate required fields
        validate_allergy_attributes!(attributes)
        
        # Format data for storage
        formatted_data = format_allergy_data(attributes)
        
        # Store to allergy file (^GMR(120.8))
        adapter.set_global("^GMR", "120.8", ien, "0", formatted_data)
        
        # Set patient cross-reference
        adapter.set_global("^GMR", "120.8", "B", patient_dfn, ien, "")
        
        # Return allergy instance
        allergy = new(ien, adapter)
        allergy.send(:load_data, formatted_data)
        allergy.instance_variable_set(:@patient_dfn, patient_dfn)
        allergy
      end
      
      # Find allergies for patient
      def self.find_by_patient(patient_dfn, adapter)
        results = []
        
        # Traverse patient cross-reference
        ien = ""
        while true
          ien = adapter.order_global("^GMR", "120.8", "B", patient_dfn, ien)
          break if ien.nil? || ien.empty?
          
          allergy = find(ien, adapter)
          results << allergy if allergy
        end
        
        results
      end
      
      # Find specific allergy
      def self.find(ien, adapter)
        data = adapter.get_global("^GMR", "120.8", ien.to_s, "0")
        return nil if data.nil? || data.empty?
        
        allergy = new(ien, adapter)
        allergy.send(:load_data, data)
        allergy
      end
      
      # Priority 3: Allergy interaction checking
      def self.check_interactions(patient_dfn, new_allergen, adapter)
        patient_allergies = find_by_patient(patient_dfn, adapter)
        interactions = []
        
        patient_allergies.each do |allergy|
          if cross_reactive?(allergy.allergen, new_allergen)
            interactions << {
              existing_allergen: allergy.allergen,
              new_allergen: new_allergen,
              interaction_type: "cross_reactive",
              severity: "high"
            }
          end
        end
        
        interactions
      end
      
      # Update allergy record
      def update(attributes)
        validate_allergy_attributes!(attributes)
        
        current_data = {
          allergen: @allergen,
          severity: @severity,
          date_entered: @date_entered
        }.merge(attributes)
        
        formatted_data = self.class.format_allergy_data(current_data)
        @adapter.set_global("^GMR", "120.8", @ien, "0", formatted_data)
        
        load_data(formatted_data)
        self
      end
      
      # Delete allergy record
      def delete
        # Remove main record
        @adapter.set_global("^GMR", "120.8", @ien, "0", "")
        
        # Clean up patient cross-reference
        if @patient_dfn
          @adapter.set_global("^GMR", "120.8", "B", @patient_dfn, @ien, "")
        end
        
        { success: true, ien: @ien, deleted: true }
      end
      
      private
      
      def load_data(data)
        fields = data.split("^")
        @allergen = fields[0]
        @severity = fields[1]
        @date_entered = DateFormatter.parse_fileman_date(fields[2])
        @reaction_type = fields[3]
      end
      
      def self.format_allergy_data(attributes)
        date_formatted = attributes[:date_entered].is_a?(Date) ?
          DateFormatter.format_for_fileman(attributes[:date_entered]) :
          attributes[:date_entered].to_s
          
        [
          attributes[:allergen],
          attributes[:severity],
          date_formatted,
          attributes[:reaction_type] || "ALLERGY"
        ].join("^")
      end
      
      def self.generate_new_ien(adapter)
        # Generate new IEN using timestamp-based approach
        base_ien = 80000
        random_increment = rand(1000..9999)
        (base_ien + random_increment).to_s
      end
      
      def self.validate_allergy_attributes!(attributes)
        raise ArgumentError, "Allergen is required" if attributes[:allergen].nil? || attributes[:allergen].strip.empty?
        raise ArgumentError, "Severity is required" if attributes[:severity].nil? || attributes[:severity].strip.empty?
        raise ArgumentError, "Invalid severity" unless %w[MILD MODERATE SEVERE].include?(attributes[:severity])
      end
      
      def self.cross_reactive?(allergen1, allergen2)
        # Simple cross-reactivity checking
        cross_reactive_groups = [
          ["PENICILLIN", "AMOXICILLIN", "AMPICILLIN"],
          ["SULFA", "SULFAMETHOXAZOLE", "SULFADIAZINE"],
          ["SHELLFISH", "IODINE", "CONTRAST DYE"]
        ]
        
        cross_reactive_groups.any? do |group|
          group.include?(allergen1.upcase) && group.include?(allergen2.upcase)
        end
      end
    end
  end
end