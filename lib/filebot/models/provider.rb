# frozen_string_literal: true

require 'date'

module FileBot
  module Models
    # Priority 3: Healthcare-specific Provider model - replaces FileMan Provider file
    class Provider
      attr_reader :ien, :name, :specialty, :license_number, :active, :adapter
      
      def initialize(ien, adapter, data = nil)
        @ien = ien.to_s
        @adapter = adapter
        load_data(data) if data
      end
      
      # Create new provider
      def self.create(attributes, adapter)
        ien = generate_new_ien(adapter)
        validate_provider_attributes!(attributes)
        
        formatted_data = format_provider_data(attributes)
        adapter.set_global("^VA", "200", ien, "0", formatted_data)
        
        # Set name cross-reference
        adapter.set_global("^VA", "200", "B", attributes[:name].upcase, ien, "")
        
        provider = new(ien, adapter)
        provider.send(:load_data, formatted_data)
        provider
      end
      
      # Find provider by IEN
      def self.find(ien, adapter)
        data = adapter.get_global("^VA", "200", ien.to_s, "0")
        return nil if data.nil? || data.empty?
        
        provider = new(ien, adapter)
        provider.send(:load_data, data)
        provider
      end
      
      # Search providers by name
      def self.search_by_name(name_pattern, adapter, limit = 50)
        results = []
        pattern = name_pattern.upcase
        
        key = ""
        count = 0
        
        while count < limit
          key = adapter.order_global("^VA", "200", "B", key)
          break if key.nil? || key.empty?
          
          if key.start_with?(pattern)
            ien = adapter.order_global("^VA", "200", "B", key, "")
            if ien && !ien.empty?
              provider = find(ien, adapter)
              results << provider if provider
              count += 1
            end
          elsif key > pattern + "~"
            break
          end
        end
        
        results
      end
      
      # Priority 3: Provider relationship validation
      def self.validate_patient_provider_relationship(patient_dfn, provider_ien, adapter)
        # Check if provider is active
        provider = find(provider_ien, adapter)
        return { valid: false, error: "Provider not found" } unless provider
        return { valid: false, error: "Provider not active" } unless provider.active
        
        # Check provider specialty restrictions
        patient = FileBot::Models::Patient.find(patient_dfn, adapter)
        return { valid: false, error: "Patient not found" } unless patient
        
        # Validate specialty can treat patient
        { valid: true, provider: provider, patient: patient }
      end
      
      # Priority 3: Provider scheduling
      def self.find_available_providers(specialty, date, adapter)
        providers = search_by_specialty(specialty, adapter)
        
        # Filter by availability (simplified)
        providers.select do |provider|
          provider.active && check_availability(provider, date, adapter)
        end
      end
      
      # Search by specialty
      def self.search_by_specialty(specialty, adapter)
        # Would implement specialty cross-reference
        # For now, search all and filter
        search_by_name("", adapter, 1000).select do |provider|
          provider.specialty && provider.specialty.upcase.include?(specialty.upcase)
        end
      end
      
      private
      
      def load_data(data)
        fields = data.split("^")
        @name = fields[0]
        @specialty = fields[1]
        @license_number = fields[2]
        @active = fields[3] == "1"
      end
      
      def self.format_provider_data(attributes)
        [
          attributes[:name],
          attributes[:specialty],
          attributes[:license_number],
          attributes[:active] ? "1" : "0"
        ].join("^")
      end
      
      def self.generate_new_ien(adapter)
        base_ien = 70000
        random_increment = rand(1000..9999)
        (base_ien + random_increment).to_s
      end
      
      def self.validate_provider_attributes!(attributes)
        raise ArgumentError, "Name is required" if attributes[:name].nil? || attributes[:name].strip.empty?
        raise ArgumentError, "Specialty is required" if attributes[:specialty].nil? || attributes[:specialty].strip.empty?
      end
      
      def self.check_availability(provider, date, adapter)
        # Simplified availability check
        # In real implementation, would check scheduling file
        true
      end
    end
  end
end