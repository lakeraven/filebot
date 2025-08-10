# frozen_string_literal: true

module FileBot
  # Core FileBot class for high-performance healthcare operations
  # Implementation-agnostic design works with any MUMPS database adapter
  class Core
    attr_reader :adapter, :config

    def initialize(adapter = nil, config = {})
      @config = config.is_a?(Hash) ? config : {}
      @adapter = adapter || create_adapter_from_config
      validate_adapter!
    end

    # Ultra-fast patient lookup using adapter-agnostic global access
    def get_patient_demographics(dfn)
      begin
        result = @adapter.get_global("^DPT", dfn.to_s, "0")
        return nil if result.nil? || result.empty?

        PatientParser.parse_zero_node(dfn, result)
      rescue => e
        puts "FileBot: Native patient lookup failed: #{e.message}" if ENV['FILEBOT_DEBUG']
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
        puts "FileBot: Native search failed: #{e.message}" if ENV['FILEBOT_DEBUG']
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
        puts "FileBot: Native patient creation failed: #{e.message}" if ENV['FILEBOT_DEBUG']
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
        puts "FileBot: Native batch retrieval failed: #{e.message}" if ENV['FILEBOT_DEBUG']
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
        puts "FileBot: Native clinical summary failed: #{e.message}" if ENV['FILEBOT_DEBUG']
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
      if errors.empty? && patient_data[:ssn]&.to_s != ""
        begin
          exists = @adapter.data_global("^DPT", "SSN", patient_data[:ssn])
          errors << "SSN already exists" if exists && exists > 0
        rescue => e
          puts "FileBot: Native validation check failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          errors << "Validation check failed"
        end
      end

      { success: errors.empty?, errors: errors }
    end

    # FIND^DIC equivalent - Find entries matching criteria
    def find_entries(file_number, search_value, search_field = nil, flags = nil, max_results = 10)
      begin
        results = []
        global_root = get_global_root(file_number)
        
        # If searching by name (default), use B cross-reference
        if search_field.nil? || search_field == ".01"
          search_value = search_value.upcase
          current_key = @adapter.order_global(global_root, "B", search_value)
          
          while current_key && current_key.start_with?(search_value) && results.length < max_results
            # Get all DFNs for this name
            dfn = @adapter.order_global(global_root, "B", current_key, "")
            while dfn && !dfn.empty? && results.length < max_results
              entry_data = @adapter.get_global(global_root, dfn, "0")
              if entry_data && !entry_data.empty?
                results << {
                  ien: dfn.to_i,
                  name: current_key,
                  data: entry_data
                }
              end
              dfn = @adapter.order_global(global_root, "B", current_key, dfn)
            end
            current_key = @adapter.order_global(global_root, "B", current_key)
          end
        else
          # Search by other fields using cross-references
          xref_name = get_cross_reference_name(file_number, search_field)
          if xref_name
            current_key = @adapter.order_global(global_root, xref_name, search_value.to_s)
            while current_key && current_key.start_with?(search_value.to_s) && results.length < max_results
              dfn = @adapter.order_global(global_root, xref_name, current_key, "")
              while dfn && !dfn.empty? && results.length < max_results
                entry_data = @adapter.get_global(global_root, dfn, "0")
                if entry_data && !entry_data.empty?
                  results << {
                    ien: dfn.to_i,
                    search_value: current_key,
                    data: entry_data
                  }
                end
                dfn = @adapter.order_global(global_root, xref_name, current_key, dfn)
              end
              current_key = @adapter.order_global(global_root, xref_name, current_key)
            end
          end
        end

        { success: true, results: results, count: results.length }
      rescue => e
        puts "FileBot: Find entries failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        { success: false, error: e.message, results: [], count: 0 }
      end
    end

    # LIST^DIC equivalent - List entries with optional screening
    def list_entries(file_number, start_from = "", fields = ".01", max_results = 20, screen = nil)
      begin
        results = []
        global_root = get_global_root(file_number)
        
        # Start from specified point or beginning
        current_dfn = start_from.empty? ? @adapter.order_global(global_root, "") : start_from
        
        while current_dfn && !current_dfn.empty? && results.length < max_results
          entry_data = @adapter.get_global(global_root, current_dfn, "0")
          
          if entry_data && !entry_data.empty?
            # Apply screening logic if provided
            if screen.nil? || apply_screen_logic(screen, entry_data)
              parsed_data = parse_entry_fields(entry_data, fields.split(";"))
              results << {
                ien: current_dfn.to_i,
                fields: parsed_data
              }
            end
          end
          
          current_dfn = @adapter.order_global(global_root, current_dfn)
        end

        { success: true, results: results, count: results.length }
      rescue => e
        puts "FileBot: List entries failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        { success: false, error: e.message, results: [], count: 0 }
      end
    end

    # DELETE^DIC equivalent - Delete entry
    def delete_entry(file_number, ien)
      begin
        global_root = get_global_root(file_number)
        
        # Get current data before deletion for cross-reference cleanup
        current_data = @adapter.get_global(global_root, ien.to_s, "0")
        return { success: false, error: "Entry not found" } if current_data.nil? || current_data.empty?

        # Remove cross-references first
        cleanup_cross_references(file_number, ien.to_s, current_data)
        
        # Delete the main entry
        @adapter.set_global("", global_root, ien.to_s)
        
        # Update file header count
        current_count = @adapter.get_global(global_root, "0") || "0"
        new_count = current_count.to_i - 1
        @adapter.set_global(new_count.to_s, global_root, "0")

        { success: true, deleted_ien: ien }
      rescue => e
        puts "FileBot: Delete entry failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        { success: false, error: e.message }
      end
    end

    # LOCK functionality - Lock entry for editing
    def lock_entry(file_number, ien, timeout = 30)
      begin
        global_root = get_global_root(file_number)
        lock_global = "#{global_root}_LOCK"
        
        # Try to acquire lock
        existing_lock = @adapter.get_global(lock_global, ien.to_s)
        if existing_lock && !existing_lock.empty?
          lock_time = existing_lock.split("^")[1].to_i
          if Time.current.to_i - lock_time < timeout
            return { success: false, error: "Entry locked by another user", locked_by: existing_lock.split("^")[0] }
          end
        end

        # Set lock
        lock_value = "#{ENV['USER'] || 'FILEBOT'}^#{Time.current.to_i}"
        @adapter.set_global(lock_value, lock_global, ien.to_s)
        
        { success: true, locked_by: ENV['USER'] || 'FILEBOT' }
      rescue => e
        puts "FileBot: Lock entry failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        { success: false, error: e.message }
      end
    end

    # UNLOCK functionality - Release lock on entry
    def unlock_entry(file_number, ien)
      begin
        global_root = get_global_root(file_number)
        lock_global = "#{global_root}_LOCK"
        
        # Remove lock
        @adapter.set_global("", lock_global, ien.to_s)
        
        { success: true }
      rescue => e
        puts "FileBot: Unlock entry failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        { success: false, error: e.message }
      end
    end

    # Get entry data (GETS^DIQ equivalent)
    def gets_entry(file_number, ien, fields, flags = "EI")
      begin
        global_root = get_global_root(file_number)
        
        # Get main entry data
        entry_data = @adapter.get_global(global_root, ien.to_s, "0")
        return { success: false, error: "Entry not found" } if entry_data.nil? || entry_data.empty?

        # Parse requested fields
        requested_fields = fields.split(";")
        result_data = {}
        
        requested_fields.each do |field|
          field_value = get_field_value(file_number, ien, field, entry_data, flags)
          result_data[field] = field_value
        end

        { success: true, data: result_data, ien: ien }
      rescue => e
        puts "FileBot: Gets entry failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        { success: false, error: e.message }
      end
    end

    # Update entry (UPDATE^DIE equivalent) 
    def update_entry(file_number, ien, field_data)
      begin
        # Lock entry for update
        lock_result = lock_entry(file_number, ien)
        return lock_result unless lock_result[:success]

        global_root = get_global_root(file_number)
        
        # Get current data
        current_data = @adapter.get_global(global_root, ien.to_s, "0")
        return { success: false, error: "Entry not found" } if current_data.nil? || current_data.empty?

        # Build updated entry
        updated_data = build_updated_entry(current_data, field_data)
        
        # Validate updated data
        validation_result = validate_entry_data(file_number, updated_data)
        unless validation_result[:success]
          unlock_entry(file_number, ien)
          return validation_result
        end

        # Update cross-references
        update_cross_references(file_number, ien.to_s, current_data, updated_data)
        
        # Update main entry
        @adapter.set_global(updated_data, global_root, ien.to_s, "0")
        
        # Release lock
        unlock_entry(file_number, ien)
        
        { success: true, updated_ien: ien }
      rescue => e
        # Always try to unlock on error
        unlock_entry(file_number, ien) rescue nil
        puts "FileBot: Update entry failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        { success: false, error: e.message }
      end
    end

    private

    def get_next_dfn
      current = @adapter.get_global("^DPT", "0") || "0"
      current.to_i + 1
    end

    # Get global root for file number
    def get_global_root(file_number)
      case file_number
      when 2
        "^DPT"
      when 200
        "^VA(200"
      when 44
        "^SC"
      when 9.6
        "^DIC(9.6"
      else
        "^DIC(#{file_number}"
      end
    end

    # Get cross-reference name for field
    def get_cross_reference_name(file_number, field)
      case field
      when ".01"
        "B"
      when ".09", "0.09"
        "SSN"
      when ".03", "0.03" 
        "DOB"
      else
        nil
      end
    end

    # Apply screen logic to entry data
    def apply_screen_logic(screen, entry_data)
      # Simple screen logic - can be expanded
      return true if screen.nil? || screen.empty?
      
      # Example: S:$P(^DPT(Y,0),"^",2)="M" - screen for males only
      if screen.include?("M")
        return entry_data.split("^")[1] == "M"
      elsif screen.include?("F")
        return entry_data.split("^")[1] == "F"
      end
      
      true
    end

    # Parse entry fields from data
    def parse_entry_fields(entry_data, fields)
      result = {}
      pieces = entry_data.split("^")
      
      fields.each do |field|
        case field
        when ".01"
          result[field] = pieces[0]
        when ".02"
          result[field] = pieces[1] 
        when ".03"
          result[field] = pieces[2]
        when ".09"
          result[field] = pieces[8]
        when ".11"
          result[field] = pieces[10]
        else
          result[field] = ""
        end
      end
      
      result
    end

    # Get field value with formatting
    def get_field_value(file_number, ien, field, entry_data, flags)
      pieces = entry_data.split("^")
      
      value = case field
      when ".01"
        pieces[0]
      when ".02"
        pieces[1]
      when ".03"
        pieces[2]
      when ".09"
        pieces[8]
      when ".11"
        pieces[10]
      else
        ""
      end

      # Apply flags formatting
      if flags.include?("I")
        # Internal format
        value
      elsif flags.include?("E") 
        # External format - add formatting
        format_field_value(file_number, field, value)
      else
        value
      end
    end

    # Format field value for external display
    def format_field_value(file_number, field, value)
      case field
      when ".02"
        case value
        when "M"
          "MALE"
        when "F"
          "FEMALE"
        else
          value
        end
      when ".03"
        # Format date
        if value.match?(/^\d{7}$/)
          year = "19#{value[0..2]}"
          month = value[3..4]
          day = value[5..6]
          "#{month}/#{day}/#{year}"
        else
          value
        end
      when ".09"
        # Format SSN
        if value.length == 9
          "#{value[0..2]}-#{value[3..4]}-#{value[5..8]}"
        else
          value
        end
      else
        value
      end
    end

    # Build updated entry from current data and changes
    def build_updated_entry(current_data, field_data)
      pieces = current_data.split("^")
      
      field_data.each do |field, new_value|
        case field
        when ".01", "0.01"
          pieces[0] = new_value
        when ".02", "0.02"
          pieces[1] = new_value
        when ".03", "0.03"
          pieces[2] = new_value
        when ".09", "0.09"
          pieces[8] = new_value
        when ".11", "0.11"
          pieces[10] = new_value
        end
      end
      
      pieces.join("^")
    end

    # Validate entry data
    def validate_entry_data(file_number, entry_data)
      # Basic validation - can be expanded with data dictionary rules
      pieces = entry_data.split("^")
      errors = []
      
      # Name required
      errors << "Name required" if pieces[0].blank?
      
      # Gender validation
      if pieces[1]&.to_s != "" && !%w[M F].include?(pieces[1])
        errors << "Invalid gender"
      end
      
      # SSN format
      if pieces[8]&.to_s != "" && !pieces[8].match?(/^\d{9}$/)
        errors << "Invalid SSN format"
      end
      
      { success: errors.empty?, errors: errors }
    end

    # Clean up cross-references for deleted entry
    def cleanup_cross_references(file_number, ien, entry_data)
      global_root = get_global_root(file_number)
      pieces = entry_data.split("^")
      
      # Remove B (name) cross-reference
      if pieces[0]&.to_s != ""
        @adapter.set_global("", global_root, "B", pieces[0].upcase, ien)
      end
      
      # Remove SSN cross-reference
      if pieces[8]&.to_s != ""
        @adapter.set_global("", global_root, "SSN", pieces[8], ien)
      end
      
      # Remove DOB cross-reference if exists
      if pieces[2]&.to_s != ""
        @adapter.set_global("", global_root, "DOB", pieces[2], ien)
      end
    end

    # Update cross-references when entry changes
    def update_cross_references(file_number, ien, old_data, new_data)
      global_root = get_global_root(file_number)
      old_pieces = old_data.split("^")
      new_pieces = new_data.split("^")
      
      # Update B (name) cross-reference if changed
      if old_pieces[0] != new_pieces[0]
        # Remove old reference
        @adapter.set_global("", global_root, "B", old_pieces[0].upcase, ien) if old_pieces[0]&.to_s != ""
        # Add new reference
        @adapter.set_global("", global_root, "B", new_pieces[0].upcase, ien) if new_pieces[0]&.to_s != ""
      end
      
      # Update SSN cross-reference if changed
      if old_pieces[8] != new_pieces[8]
        # Remove old reference
        @adapter.set_global("", global_root, "SSN", old_pieces[8], ien) if old_pieces[8]&.to_s != ""
        # Add new reference
        @adapter.set_global("", global_root, "SSN", new_pieces[8], ien) if new_pieces[8]&.to_s != ""
      end
    end

    # === Adapter Management ===

    # Get adapter information
    # @return [Hash] Adapter metadata
    def adapter_info
      {
        type: @adapter.adapter_type,
        version: @adapter.version_info,
        capabilities: @adapter.capabilities,
        connected: @adapter.connected?
      }
    end

    # Test adapter connectivity
    # @return [Hash] Connection test result
    def test_connection
      @adapter.test_connection
    end

    # Switch to a different adapter
    # @param new_adapter [Symbol, BaseAdapter] New adapter type or instance
    # @param config [Hash] Configuration for new adapter
    def switch_adapter!(new_adapter, config = {})
      @adapter.close if @adapter.respond_to?(:close)
      
      @adapter = if new_adapter.is_a?(Symbol)
        DatabaseAdapterFactory.create_adapter(new_adapter, config)
      else
        new_adapter
      end
      
      validate_adapter!
      puts "FileBot: Switched to #{@adapter.adapter_type} adapter" if ENV['FILEBOT_DEBUG']
    end

    private

    def create_adapter_from_config
      adapter_type = @config[:adapter] || :auto_detect
      DatabaseAdapterFactory.create_adapter(adapter_type, @config)
    end

    def validate_adapter!
      unless @adapter.respond_to?(:get_global) && 
             @adapter.respond_to?(:set_global) &&
             @adapter.respond_to?(:order_global) &&
             @adapter.respond_to?(:data_global)
        raise ArgumentError, "Adapter must implement BaseAdapter interface"
      end

      unless @adapter.respond_to?(:adapter_type)
        raise ArgumentError, "Adapter must provide adapter_type method"
      end

      puts "FileBot: Using #{@adapter.adapter_type} adapter" if ENV['FILEBOT_DEBUG']
    end
  end
end
