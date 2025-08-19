# frozen_string_literal: true

require_relative 'base_adapter'

module FileBot
  module Adapters
    # IRIS database adapter using pure Java Native API
    class IRISAdapter < BaseAdapter
      def initialize(config = {})
        super(config)
      end

      def get_global(global, *subscripts)
        return "" if @iris_native.nil?
        
        # Use Native SDK direct global access
        begin
          # Convert ^GLOBAL format to just GLOBAL for Native SDK
          clean_global = global.sub(/^\^/, '')
          
          # Validate global name (IRIS doesn't allow underscores in many contexts)
          if clean_global.include?('_')
            puts "FileBot: Warning - global name '#{clean_global}' contains underscore, may cause IRIS syntax errors" if ENV['FILEBOT_DEBUG']
            # Convert underscores to valid characters for IRIS
            clean_global = clean_global.gsub('_', 'X')
          end
          
          if subscripts.empty?
            # Get global root
            @iris_native.getString(clean_global)
          else
            # Get global with subscripts
            @iris_native.getString(clean_global, *subscripts)
          end
        rescue => e
          puts "FileBot: Global GET failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          ""
        end
      end

      def set_global(global, *subscripts_and_value)
        return "" if @iris_native.nil?
        
        value = subscripts_and_value.pop
        subscripts = subscripts_and_value
        
        # Use Native SDK direct global access
        begin
          # Convert ^GLOBAL format to just GLOBAL for Native SDK
          clean_global = global.sub(/^\^/, '')
          
          # Validate global name (IRIS doesn't allow underscores in many contexts)
          if clean_global.include?('_')
            puts "FileBot: Warning - global name '#{clean_global}' contains underscore, may cause IRIS syntax errors" if ENV['FILEBOT_DEBUG']
            # Convert underscores to valid characters for IRIS
            clean_global = clean_global.gsub('_', 'X')
          end
          
          if subscripts.empty?
            # Set global root
            @iris_native.set(value, clean_global)
          else
            # Set global with subscripts
            @iris_native.set(value, clean_global, *subscripts)
          end
          
          "OK"
        rescue => e
          puts "FileBot: Global SET failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          ""
        end
      end

      def kill_global(global, *subscripts)
        return false if @iris_native.nil?
        
        begin
          # Convert ^GLOBAL format to just GLOBAL for Native SDK
          clean_global = global.sub(/^\^/, '')
          
          # Validate global name
          if clean_global.include?('_')
            puts "FileBot: Warning - global name '#{clean_global}' contains underscore, may cause IRIS syntax errors" if ENV['FILEBOT_DEBUG']
            clean_global = clean_global.gsub('_', 'X')
          end
          
          if subscripts.empty?
            # Kill entire global
            @iris_native.kill(clean_global)
          else
            # Kill specific subscripted node
            @iris_native.kill(clean_global, *subscripts)
          end
          
          puts "KILL(#{clean_global}#{subscripts.empty? ? '' : ','+subscripts.join(',')}) successful" if ENV['FILEBOT_DEBUG']
          true
        rescue => e
          puts "FileBot: Global KILL failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          false
        end
      end

      def order_global(global, *subscripts)
        return "" if @iris_native.nil?
        begin
          clean_global = global.sub(/^\^/, '')
          
          if subscripts.empty?
            # Get first subscript at root level
            iterator = @iris_native.getIRISIterator(clean_global)
            if iterator.hasNext
              iterator.next
              next_sub = iterator.getSubscriptValue
              puts "ORDER next (first): #{next_sub}" if ENV['FILEBOT_DEBUG']
              next_sub.to_s
            else
              puts "ORDER next: no subscripts found" if ENV['FILEBOT_DEBUG']
              ""
            end
          else
            # Handle multi-level subscripts
            last_subscript = subscripts.last
            parent_subscripts = subscripts[0..-2]
            
            if last_subscript == "0"
              # Get first subscript at this level
              iterator = if parent_subscripts.empty?
                @iris_native.getIRISIterator(clean_global)
              else
                @iris_native.getIRISIterator(clean_global, *parent_subscripts)
              end
              
              if iterator.hasNext
                iterator.next
                next_sub = iterator.getSubscriptValue
                puts "ORDER next (first at level): #{next_sub}" if ENV['FILEBOT_DEBUG']
                next_sub.to_s
              else
                puts "ORDER next: no subscripts at level" if ENV['FILEBOT_DEBUG']
                ""
              end
            else
              # Find next subscript after the current one at this level
              iterator = if parent_subscripts.empty?
                @iris_native.getIRISIterator(clean_global)
              else
                @iris_native.getIRISIterator(clean_global, *parent_subscripts)
              end
              
              found_target = false
              while iterator.hasNext
                iterator.next
                current_sub = iterator.getSubscriptValue.to_s
                
                if found_target
                  puts "ORDER next: #{current_sub}" if ENV['FILEBOT_DEBUG']
                  return current_sub
                elsif current_sub == last_subscript
                  found_target = true
                end
              end
              
              puts "ORDER next: no more subscripts after #{last_subscript}" if ENV['FILEBOT_DEBUG']
              ""
            end
          end
        rescue => e
          puts "ORDER error: #{e.message}" if ENV['FILEBOT_DEBUG']
          ""
        end
      end

      def query_global(global, *subscripts)
        return "" if @iris_native.nil?
        begin
          clean_global = global.sub(/^\^/, '')
          
          # $QUERY returns the next global reference in collating sequence
          # This provides more powerful traversal than $ORDER
          if subscripts.empty?
            # Query at global level
            query_result = @iris_native.queryGet(clean_global)
          else
            # Query with specific subscripts
            query_result = @iris_native.queryGet(clean_global, *subscripts)
          end
          
          # Extract the next reference from query result
          if query_result && query_result.hasNext
            next_ref = query_result.nextSubscript
            puts "QUERY next: #{next_ref}" if ENV['FILEBOT_DEBUG']
            next_ref.to_s
          else
            puts "QUERY: no more references" if ENV['FILEBOT_DEBUG']
            ""
          end
        rescue => e
          puts "QUERY error: #{e.message}" if ENV['FILEBOT_DEBUG']
          ""
        end
      end

      def data_global(global, *subscripts)
        return 0 if @iris_native.nil?
        begin
          clean_global = global.sub(/^\^/, '')
          
          # MUMPS $DATA function returns:
          # 0 = undefined (node does not exist)
          # 1 = defined, has value but no descendants  
          # 10 = defined, has descendants but no value
          # 11 = defined, has both value and descendants
          
          has_value = false
          has_descendants = false
          
          # Check if the node has a value using Native SDK isDefined
          begin
            has_value = if subscripts.empty?
              @iris_native.isDefined(clean_global) 
            else
              @iris_native.isDefined(clean_global, *subscripts)
            end
            
            # Double-check with getString for accuracy
            if has_value
              val = if subscripts.empty?
                @iris_native.getString(clean_global)
              else
                @iris_native.getString(clean_global, *subscripts)
              end
              has_value = !(val.nil? || val.to_s.empty?)
            end
          rescue => e
            puts "DATA value check error: #{e.message}" if ENV['FILEBOT_DEBUG']
            has_value = false
          end
          
          # Check if the node has descendants using iterator
          begin
            iterator = @iris_native.getIRISIterator(clean_global, *subscripts)
            has_descendants = iterator.hasNext
          rescue => e
            puts "DATA descendant check error: #{e.message}" if ENV['FILEBOT_DEBUG']
            has_descendants = false
          end
          
          # Calculate $DATA return value
          data_val = 0
          data_val += 1 if has_value
          data_val += 10 if has_descendants
          
          puts "DATA(#{clean_global}#{subscripts.empty? ? '' : ','+subscripts.join(',')}) = #{data_val}" if ENV['FILEBOT_DEBUG']
          data_val
        rescue => e
          puts "DATA error: #{e.message}" if ENV['FILEBOT_DEBUG']
          0
        end
      end

      # === BaseAdapter Interface Implementation ===

      def adapter_type
        :iris
      end

      def version_info
        {
          adapter_version: "1.0.0",
          database_version: iris_version || "unknown"
        }
      end

      def capabilities
        {
          transactions: true,
          locking: true,
          mumps_execution: true,
          concurrent_access: true,
          cross_references: true,
          unicode_support: true
        }
      end

      def connected?
        !@iris_native.nil? && !@jdbc_connection.nil? && !@jdbc_connection.isClosed rescue false
      end

      # === Benchmark Compatibility Methods ===
      
      # Wrapper for order_global to match benchmark expectations
      def get_next_global(global, *subscripts)
        order_global(global, *subscripts)
      end
      
      # Wrapper for data_global to match benchmark expectations  
      def global_exists(global, *subscripts)
        data_global(global, *subscripts) > 0
      end

      # === Cross-Reference Support (FileMan B Index) ===
      
      def build_cross_reference(file_global, field, value, ien)
        # Create standard FileMan B index: ^GLOBAL("B",VALUE,IEN)=""
        begin
          set_global(file_global, "B", value, ien, "")
          puts "Cross-reference built: #{file_global}(\"B\",\"#{value}\",#{ien})" if ENV['FILEBOT_DEBUG']
          true
        rescue => e
          puts "Cross-reference build failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          false
        end
      end
      
      def find_by_cross_reference(file_global, field, value)
        # Use FileMan B index to find records: ^GLOBAL("B",VALUE,IEN)
        results = []
        begin
          # Check if this value exists in the cross-reference
          data_val = data_global(file_global, "B", value)
          if data_val >= 10
            # Walk through all IENs for this value
            current_ien = "0"
            while true
              next_ien = order_global(file_global, "B", value, current_ien)
              break if next_ien.empty?
              
              # Verify this is actually an IEN (not another value)
              if next_ien.match(/^\d+$/)
                results << next_ien
              end
              current_ien = next_ien
              break if results.length > 100  # Safety limit
            end
          end
        rescue => e
          puts "Cross-reference lookup failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        end
        
        results
      end
      
      def delete_cross_reference(file_global, field, value, ien)
        # Remove from FileMan B index
        begin
          kill_global(file_global, "B", value, ien)
          puts "Cross-reference deleted: #{file_global}(\"B\",\"#{value}\",#{ien})" if ENV['FILEBOT_DEBUG']
          true
        rescue => e
          puts "Cross-reference delete failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          false
        end
      end

      # === FileMan Validation Framework ===
      
      def validate_field(file_global, field_number, value, ien = nil)
        # FileMan-style field validation
        validation_errors = []
        
        # Get field definition (simulated - in real FileMan this comes from ^DD)
        field_def = get_field_definition(file_global, field_number)
        
        # Required field validation
        if field_def[:required] && (value.nil? || value.to_s.strip.empty?)
          validation_errors << "#{field_def[:name]} is required"
        end
        
        # Data type validation
        unless validate_data_type(value, field_def[:type])
          validation_errors << "#{field_def[:name]} must be #{field_def[:type]}"
        end
        
        # Length validation
        if field_def[:max_length] && value.to_s.length > field_def[:max_length]
          validation_errors << "#{field_def[:name]} exceeds maximum length of #{field_def[:max_length]}"
        end
        
        # Pattern validation (skip for empty optional fields)
        if field_def[:pattern] && !value.to_s.strip.empty? && !value.to_s.match(field_def[:pattern])
          validation_errors << "#{field_def[:name]} format is invalid"
        end
        
        # Uniqueness validation (if specified)
        if field_def[:unique] && ien
          existing_ien = find_by_cross_reference(file_global, field_number, value.to_s).first
          if existing_ien && existing_ien != ien.to_s
            validation_errors << "#{field_def[:name]} must be unique - already exists in record #{existing_ien}"
          end
        end
        
        # Custom validation rules
        if field_def[:custom_validator]
          custom_errors = field_def[:custom_validator].call(value, ien)
          validation_errors.concat(custom_errors) if custom_errors
        end
        
        {
          valid: validation_errors.empty?,
          errors: validation_errors,
          field: field_def[:name]
        }
      end
      
      def validate_record(file_global, ien, data = {})
        # Validate entire record
        all_errors = []
        field_results = {}
        
        # Get current record data if not provided
        if data.empty? && ien
          # Load current field values
          field_definitions(file_global).each do |field_num, field_def|
            current_value = get_global(file_global, ien, field_num)
            data[field_num] = current_value unless current_value.empty?
          end
        end
        
        # Validate each field
        field_definitions(file_global).each do |field_num, field_def|
          value = data[field_num]
          result = validate_field(file_global, field_num, value, ien)
          field_results[field_num] = result
          all_errors.concat(result[:errors])
        end
        
        # Cross-field validation
        cross_field_errors = validate_cross_fields(file_global, data, ien)
        all_errors.concat(cross_field_errors)
        
        {
          valid: all_errors.empty?,
          errors: all_errors,
          field_results: field_results
        }
      end
      
      def safe_set_global(file_global, ien, field_number, value)
        # Validated SET operation
        validation_result = validate_field(file_global, field_number, value, ien)
        
        if validation_result[:valid]
          # Get field definition for cross-reference handling
          field_def = get_field_definition(file_global, field_number)
          
          # Remove old cross-reference if this field is indexed
          if field_def[:indexed]
            old_value = get_global(file_global, ien, field_number)
            delete_cross_reference(file_global, field_number, old_value, ien) unless (old_value.nil? || old_value.empty?)
          end
          
          # Set the new value
          set_result = set_global(file_global, ien, field_number, value)
          
          # Build new cross-reference if this field is indexed
          if field_def[:indexed] && set_result == "OK"
            build_cross_reference(file_global, field_number, value, ien)
          end
          
          {
            success: set_result == "OK",
            validation: validation_result
          }
        else
          {
            success: false,
            validation: validation_result
          }
        end
      end
      
      def get_field_definition(file_global, field_number)
        # In real FileMan, this would come from ^DD global
        # For now, return healthcare-specific field definitions
        field_definitions(file_global)[field_number] || default_field_definition
      end
      
      private
      
      def validate_data_type(value, type)
        return true if value.nil? || value.to_s.empty?
        
        case type
        when :string, :text
          true
        when :number, :numeric
          value.to_s.match(/^\d+(\.\d+)?$/)
        when :date
          validate_fileman_date(value)
        when :ssn
          value.to_s.match(/^\d{9}$/)
        when :name
          value.to_s.match(/^[A-Z]+,[A-Z]+/)
        when :phone
          value.to_s.match(/^\d{10}$/) || value.to_s.match(/^\(\d{3}\)\s?\d{3}-\d{4}$/)
        else
          true
        end
      end
      
      def validate_fileman_date(value)
        # FileMan internal date format: YYYMMDD (where YYY = year - 1700)
        return false unless value.to_s.match(/^\d{7}$/)
        
        date_str = value.to_s
        year = date_str[0,3].to_i + 1700
        month = date_str[3,2].to_i
        day = date_str[5,2].to_i
        
        return false if month < 1 || month > 12
        return false if day < 1 || day > 31
        return false if year < 1800 || year > 2200
        
        # More detailed date validation could be added here
        true
      end
      
      def field_definitions(file_global)
        # Healthcare field definitions (simulating ^DD global)
        case file_global
        when 'DPT', 'PATIENT'
          {
            '.01' => {
              name: 'NAME',
              type: :name,
              required: true,
              max_length: 30,
              pattern: /^[A-Z]+,[A-Z]+/,
              indexed: true,
              unique: false,
              input_transform: :name_format,
              output_transform: :name_display
            },
            '.02' => {
              name: 'SEX',
              type: :string,
              required: true,
              max_length: 1,
              pattern: /^[MF]$/,
              indexed: false,
              unique: false,
              input_transform: :uppercase,
              output_transform: :none
            },
            '.03' => {
              name: 'DATE OF BIRTH',
              type: :date,
              required: true,
              max_length: 7,
              indexed: false,
              unique: false,
              input_transform: :date_format,
              output_transform: :date_display
            },
            '.09' => {
              name: 'SOCIAL SECURITY NUMBER',
              type: :ssn,
              required: false,
              max_length: 9,
              pattern: /^\d{9}$/,
              indexed: true,
              unique: true,
              input_transform: :ssn_format,
              output_transform: :ssn_display
            },
            '.13' => {
              name: 'PHONE NUMBER',
              type: :phone,
              required: false,
              max_length: 15,
              indexed: false,
              unique: false,
              input_transform: :phone_format,
              output_transform: :phone_display
            }
          }
        else
          {}
        end
      end
      
      def default_field_definition
        {
          name: 'UNKNOWN FIELD',
          type: :string,
          required: false,
          max_length: 255,
          indexed: false,
          unique: false
        }
      end
      
      def validate_cross_fields(file_global, data, ien)
        # Cross-field validation rules
        errors = []
        
        case file_global
        when 'DPT', 'PATIENT'
          # Healthcare-specific cross-field validations
          
          # Date of birth should not be in the future
          if data['.03']
            dob_internal = data['.03'].to_s
            if validate_fileman_date(dob_internal)
              dob_year = dob_internal[0,3].to_i + 1700
              current_year = Time.now.year
              if dob_year > current_year
                errors << "Date of birth cannot be in the future"
              end
              if dob_year < current_year - 150
                errors << "Date of birth indicates age over 150 years"
              end
            end
          end
          
          # Name and SSN combination should be logical
          if data['.01'] && data['.09']
            name = data['.01'].to_s
            ssn = data['.09'].to_s
            
            # Basic check: ensure name has reasonable format with SSN
            if name.length < 5 && ssn.length == 9
              errors << "Name appears too short for a patient with SSN"
            end
          end
        end
        
        errors
      end
      
      public

      # === FileMan Date/Time Utilities ===
      
      def fileman_today
        # Return today's date in FileMan internal format (YYYMMDD)
        today = Time.now
        year_offset = today.year - 1700
        sprintf("%03d%02d%02d", year_offset, today.month, today.day)
      end
      
      def fileman_now
        # Return current date/time in FileMan format (YYYMMDD.HHMMSS)
        now = Time.now
        year_offset = now.year - 1700
        date_part = sprintf("%03d%02d%02d", year_offset, now.month, now.day)
        time_part = sprintf("%02d%02d%02d", now.hour, now.min, now.sec)
        "#{date_part}.#{time_part}"
      end
      
      def parse_fileman_date(fileman_date)
        # Convert FileMan internal date to Ruby Date object
        return nil unless validate_fileman_date(fileman_date)
        
        date_str = fileman_date.to_s
        year = date_str[0,3].to_i + 1700
        month = date_str[3,2].to_i
        day = date_str[5,2].to_i
        
        begin
          Date.new(year, month, day)
        rescue
          nil
        end
      end
      
      def parse_fileman_datetime(fileman_datetime)
        # Convert FileMan internal date/time to Ruby Time object
        parts = fileman_datetime.to_s.split('.')
        date_part = parts[0]
        time_part = parts[1] || "000000"
        
        return nil unless validate_fileman_date(date_part)
        
        year = date_part[0,3].to_i + 1700
        month = date_part[3,2].to_i
        day = date_part[5,2].to_i
        
        hour = time_part[0,2].to_i
        minute = time_part[2,2].to_i
        second = time_part[4,2].to_i
        
        begin
          Time.new(year, month, day, hour, minute, second)
        rescue
          nil
        end
      end
      
      def format_external_date(fileman_date, format = :standard)
        # Convert FileMan date to human-readable format
        ruby_date = parse_fileman_date(fileman_date)
        return "" unless ruby_date
        
        case format
        when :standard
          ruby_date.strftime("%m/%d/%Y")
        when :long
          ruby_date.strftime("%B %d, %Y")
        when :short
          ruby_date.strftime("%m/%d/%y")
        when :iso
          ruby_date.strftime("%Y-%m-%d")
        when :fileman_external
          # FileMan external format: MMM DD,YYYY
          ruby_date.strftime("%b %d,%Y").upcase
        else
          ruby_date.strftime("%m/%d/%Y")
        end
      end
      
      def date_add_days(fileman_date, days)
        # Add days to a FileMan date
        ruby_date = parse_fileman_date(fileman_date)
        return "" unless ruby_date
        
        new_date = ruby_date + days
        year_offset = new_date.year - 1700
        sprintf("%03d%02d%02d", year_offset, new_date.month, new_date.day)
      end
      
      def date_diff_days(fileman_date1, fileman_date2)
        # Calculate difference in days between two FileMan dates
        date1 = parse_fileman_date(fileman_date1)
        date2 = parse_fileman_date(fileman_date2)
        
        return nil unless date1 && date2
        (date2 - date1).to_i
      end
      
      def age_in_years(birth_date, as_of_date = nil)
        # Calculate age in years from FileMan birth date
        birth = parse_fileman_date(birth_date)
        return nil unless birth
        
        as_of = as_of_date ? parse_fileman_date(as_of_date) : Date.today
        return nil unless as_of
        
        age = as_of.year - birth.year
        age -= 1 if as_of < birth + age * 365  # Approximate birthday check
        age
      end
      
      def convert_external_date(external_date)
        # Convert various external date formats to FileMan internal
        return "" if external_date.nil? || external_date.to_s.strip.empty?
        
        date_str = external_date.to_s.strip
        ruby_date = nil
        
        # Try different common formats
        patterns = [
          ['%m/%d/%Y', date_str],      # MM/DD/YYYY
          ['%m-%d-%Y', date_str],      # MM-DD-YYYY
          ['%Y-%m-%d', date_str],      # YYYY-MM-DD (ISO)
          ['%b %d,%Y', date_str],      # MMM DD,YYYY
          ['%B %d, %Y', date_str]      # Month DD, YYYY
        ]
        
        # Handle 2-digit years specially
        if date_str.match(/^\d{1,2}\/\d{1,2}\/\d{2}$/)
          # MM/DD/YY format - need to interpret 2-digit year
          parts = date_str.split('/')
          year_2digit = parts[2].to_i
          # Assume 00-30 is 2000s, 31-99 is 1900s
          full_year = year_2digit <= 30 ? 2000 + year_2digit : 1900 + year_2digit
          date_str = "#{parts[0]}/#{parts[1]}/#{full_year}"
          patterns << ['%m/%d/%Y', date_str]
        end
        
        patterns.each do |pattern, str|
          begin
            ruby_date = Date.strptime(str, pattern)
            break
          rescue
            next
          end
        end
        
        return "" unless ruby_date
        
        # Convert to FileMan format
        year_offset = ruby_date.year - 1700
        sprintf("%03d%02d%02d", year_offset, ruby_date.month, ruby_date.day)
      end
      
      def validate_date_range(start_date, end_date)
        # Validate that date range is logical
        start_ruby = parse_fileman_date(start_date)
        end_ruby = parse_fileman_date(end_date)
        
        return { valid: false, error: "Invalid start date" } unless start_ruby
        return { valid: false, error: "Invalid end date" } unless end_ruby
        return { valid: false, error: "End date must be after start date" } if end_ruby < start_ruby
        
        { valid: true, error: nil }
      end

      # === FileMan Input/Output Transforms ===
      
      def apply_input_transform(file_global, field_number, value)
        # Apply FileMan input transform to convert external to internal format
        return value if value.nil? || value.to_s.strip.empty?
        
        field_def = get_field_definition(file_global, field_number)
        transform_type = field_def[:input_transform] || :none
        
        case transform_type
        when :none
          value.to_s
        when :uppercase
          value.to_s.upcase
        when :name_format
          format_name_input(value.to_s)
        when :ssn_format
          format_ssn_input(value.to_s)
        when :phone_format
          format_phone_input(value.to_s)
        when :date_format
          convert_external_date(value.to_s)
        when :numeric_format
          format_numeric_input(value.to_s)
        when :remove_punctuation
          value.to_s.gsub(/[^\w\s]/, '').strip
        when :custom
          if field_def[:custom_input_transform]
            field_def[:custom_input_transform].call(value.to_s)
          else
            value.to_s
          end
        else
          value.to_s
        end
      end
      
      def apply_output_transform(file_global, field_number, internal_value)
        # Apply FileMan output transform to convert internal to external format
        return "" if internal_value.nil? || internal_value.to_s.strip.empty?
        
        field_def = get_field_definition(file_global, field_number)
        transform_type = field_def[:output_transform] || :none
        
        case transform_type
        when :none
          internal_value.to_s
        when :name_display
          format_name_output(internal_value.to_s)
        when :ssn_display
          format_ssn_output(internal_value.to_s)
        when :phone_display
          format_phone_output(internal_value.to_s)
        when :date_display
          format_external_date(internal_value.to_s, :standard)
        when :date_long
          format_external_date(internal_value.to_s, :long)
        when :yes_no
          internal_value.to_s == "1" ? "YES" : "NO"
        when :currency
          format_currency_output(internal_value.to_s)
        when :custom
          if field_def[:custom_output_transform]
            field_def[:custom_output_transform].call(internal_value.to_s)
          else
            internal_value.to_s
          end
        else
          internal_value.to_s
        end
      end
      
      def transformed_set_global(file_global, ien, field_number, external_value)
        # Set global with input transform applied
        internal_value = apply_input_transform(file_global, field_number, external_value)
        safe_set_global(file_global, ien, field_number, internal_value)
      end
      
      def transformed_get_global(file_global, ien, field_number)
        # Get global with output transform applied
        internal_value = get_global(file_global, ien, field_number)
        apply_output_transform(file_global, field_number, internal_value)
      end
      
      private
      
      def format_name_input(name_str)
        # Convert name to FileMan standard format: LAST,FIRST MIDDLE
        cleaned = name_str.strip.upcase
        
        # Handle various input formats
        if cleaned.include?(',')
          # Already in LAST,FIRST format
          parts = cleaned.split(',')
          last = parts[0].strip
          first = parts[1].strip if parts[1]
          "#{last},#{first}"
        elsif cleaned.include?(' ')
          # Assume FIRST LAST or FIRST MIDDLE LAST format
          parts = cleaned.split(' ')
          if parts.length == 2
            "#{parts[1]},#{parts[0]}"  # FIRST LAST -> LAST,FIRST
          else
            last = parts.last
            first_middle = parts[0..-2].join(' ')
            "#{last},#{first_middle}"
          end
        else
          # Single name - assume it's the last name
          "#{cleaned},"
        end
      end
      
      def format_name_output(internal_name)
        # Convert internal name to display format: FIRST LAST
        return "" if internal_name.empty?
        
        if internal_name.include?(',')
          parts = internal_name.split(',')
          last = parts[0].strip
          first = parts[1].strip if parts[1]
          first ? "#{first} #{last}" : last
        else
          internal_name
        end
      end
      
      def format_ssn_input(ssn_str)
        # Remove formatting and return 9 digits
        digits_only = ssn_str.gsub(/\D/, '')
        digits_only.length == 9 ? digits_only : ssn_str
      end
      
      def format_ssn_output(internal_ssn)
        # Format SSN for display: XXX-XX-XXXX
        return "" if internal_ssn.length != 9
        "#{internal_ssn[0,3]}-#{internal_ssn[3,2]}-#{internal_ssn[5,4]}"
      end
      
      def format_phone_input(phone_str)
        # Remove formatting and return 10 digits
        digits_only = phone_str.gsub(/\D/, '')
        digits_only.length == 10 ? digits_only : phone_str
      end
      
      def format_phone_output(internal_phone)
        # Format phone for display: (XXX) XXX-XXXX
        return "" if internal_phone.length != 10
        "(#{internal_phone[0,3]}) #{internal_phone[3,3]}-#{internal_phone[6,4]}"
      end
      
      def format_numeric_input(numeric_str)
        # Clean numeric input
        cleaned = numeric_str.gsub(/[^\d.]/, '')
        cleaned.empty? ? "0" : cleaned
      end
      
      def format_currency_output(internal_value)
        # Format currency for display: $X,XXX.XX
        begin
          amount = Float(internal_value)
          "$#{sprintf('%.2f', amount)}"
        rescue
          internal_value
        end
      end
      
      public

      # === Comprehensive Error Handling and Logging ===
      
      class FileManError < StandardError
        attr_reader :error_code, :field, :value, :context
        
        def initialize(message, error_code: nil, field: nil, value: nil, context: {})
          super(message)
          @error_code = error_code
          @field = field
          @value = value
          @context = context
        end
        
        def to_hash
          {
            message: message,
            error_code: error_code,
            field: field,
            value: value,
            context: context,
            timestamp: Time.now.iso8601
          }
        end
      end
      
      class ValidationError < FileManError; end
      class DatabaseError < FileManError; end
      class TransformError < FileManError; end
      class CrossReferenceError < FileManError; end
      
      def handle_operation_with_retry(operation_name, max_retries: 3, &block)
        # Wrapper for operations that may need retry logic
        retries = 0
        
        begin
          result = yield
          log_operation_success(operation_name)
          result
        rescue => e
          retries += 1
          log_operation_error(operation_name, e, retries)
          
          if retries <= max_retries && retryable_error?(e)
            wait_time = 2 ** retries # Exponential backoff
            sleep(wait_time)
            retry
          else
            raise DatabaseError.new(
              "Operation #{operation_name} failed after #{retries} attempts: #{e.message}",
              error_code: 'DB_OPERATION_FAILED',
              context: { operation: operation_name, retries: retries, original_error: e.class.name }
            )
          end
        end
      end
      
      def safe_global_operation(operation_type, global, *args, &block)
        # Wrapper for all global operations with error handling
        begin
          validate_global_name(global)
          validate_subscripts(*args) if args.any?
          
          result = yield
          
          log_global_operation(operation_type, global, args, true)
          result
        rescue ValidationError => e
          # Re-raise validation errors as-is
          raise e
        rescue Java::JavaSql::SQLException => e
          handle_sql_exception(operation_type, global, args, e)
        rescue Java::JavaLang::Exception => e
          handle_java_exception(operation_type, global, args, e)
        rescue => e
          handle_ruby_exception(operation_type, global, args, e)
        end
      end
      
      def validate_connection_health
        # Check if IRIS connection is healthy
        unless connected?
          raise DatabaseError.new(
            "IRIS connection is not available",
            error_code: 'CONNECTION_LOST'
          )
        end
        
        # Test basic operation
        begin
          @iris_native.getString("HEALTHCHECK")
          true
        rescue => e
          raise DatabaseError.new(
            "IRIS connection health check failed: #{e.message}",
            error_code: 'CONNECTION_UNHEALTHY',
            context: { test_operation: 'getString' }
          )
        end
      end
      
      def with_error_context(context = {})
        # Add context to errors for better debugging
        Thread.current[:filebot_error_context] = context
        yield
      ensure
        Thread.current[:filebot_error_context] = nil
      end
      
      def enhanced_set_global(global, *subscripts_and_value)
        # SET with comprehensive error handling
        safe_global_operation(:set, global, *subscripts_and_value) do
          handle_operation_with_retry("SET #{global}") do
            validate_connection_health
            set_global(global, *subscripts_and_value)
          end
        end
      end
      
      def enhanced_get_global(global, *subscripts)
        # GET with comprehensive error handling
        safe_global_operation(:get, global, *subscripts) do
          handle_operation_with_retry("GET #{global}") do
            validate_connection_health
            get_global(global, *subscripts)
          end
        end
      end
      
      def enhanced_kill_global(global, *subscripts)
        # KILL with comprehensive error handling
        safe_global_operation(:kill, global, *subscripts) do
          handle_operation_with_retry("KILL #{global}") do
            validate_connection_health
            kill_global(global, *subscripts)
          end
        end
      end
      
      def robust_patient_operation(operation_name, ien, &block)
        # Healthcare-specific operation wrapper
        with_error_context(operation: operation_name, patient_ien: ien) do
          begin
            validate_ien(ien)
            yield
          rescue ValidationError => e
            log_healthcare_error(operation_name, ien, e)
            raise e
          rescue => e
            healthcare_error = DatabaseError.new(
              "Patient operation #{operation_name} failed for IEN #{ien}: #{e.message}",
              error_code: 'PATIENT_OPERATION_FAILED',
              context: { patient_ien: ien, operation: operation_name }
            )
            log_healthcare_error(operation_name, ien, healthcare_error)
            raise healthcare_error
          end
        end
      end
      
      private
      
      def validate_global_name(global)
        clean_name = global.to_s.sub(/^\^/, '')
        
        if clean_name.empty?
          raise ValidationError.new(
            "Global name cannot be empty",
            error_code: 'INVALID_GLOBAL_NAME',
            value: global
          )
        end
        
        unless clean_name.match(/^[A-Za-z][A-Za-z0-9]*$/)
          raise ValidationError.new(
            "Invalid global name format: #{clean_name}",
            error_code: 'INVALID_GLOBAL_FORMAT',
            value: global
          )
        end
      end
      
      def validate_subscripts(*subscripts)
        subscripts.each_with_index do |sub, index|
          if sub.nil?
            raise ValidationError.new(
              "Subscript #{index} cannot be nil",
              error_code: 'NULL_SUBSCRIPT',
              value: sub,
              context: { subscript_index: index }
            )
          end
          
          if sub.to_s.length > 255
            raise ValidationError.new(
              "Subscript #{index} exceeds maximum length of 255",
              error_code: 'SUBSCRIPT_TOO_LONG',
              value: sub,
              context: { subscript_index: index, length: sub.to_s.length }
            )
          end
        end
      end
      
      def validate_ien(ien)
        unless ien.to_s.match(/^\d+$/)
          raise ValidationError.new(
            "Invalid IEN format: #{ien}",
            error_code: 'INVALID_IEN',
            value: ien
          )
        end
        
        ien_num = ien.to_i
        if ien_num <= 0 || ien_num > 999999999
          raise ValidationError.new(
            "IEN out of valid range: #{ien}",
            error_code: 'IEN_OUT_OF_RANGE', 
            value: ien
          )
        end
      end
      
      def retryable_error?(error)
        # Determine if an error is worth retrying
        case error
        when Java::JavaSql::SQLException
          # SQL connection issues might be temporary
          error.message.include?('connection') || error.message.include?('timeout')
        when Java::JavaLang::Exception
          # Some Java exceptions might be retryable
          error.message.include?('timeout') || error.message.include?('unavailable')
        else
          false
        end
      end
      
      def handle_sql_exception(operation_type, global, args, exception)
        error_message = "SQL error during #{operation_type} on #{global}: #{exception.message}"
        
        raise DatabaseError.new(
          error_message,
          error_code: 'SQL_EXCEPTION',
          context: {
            operation_type: operation_type,
            global: global,
            args: args,
            sql_state: exception.getSQLState,
            error_code: exception.getErrorCode
          }
        )
      end
      
      def handle_java_exception(operation_type, global, args, exception)
        error_message = "Java error during #{operation_type} on #{global}: #{exception.message}"
        
        raise DatabaseError.new(
          error_message,
          error_code: 'JAVA_EXCEPTION',
          context: {
            operation_type: operation_type,
            global: global,
            args: args,
            java_class: exception.class.name
          }
        )
      end
      
      def handle_ruby_exception(operation_type, global, args, exception)
        error_message = "Ruby error during #{operation_type} on #{global}: #{exception.message}"
        
        raise DatabaseError.new(
          error_message,
          error_code: 'RUBY_EXCEPTION',
          context: {
            operation_type: operation_type,
            global: global,
            args: args,
            ruby_class: exception.class.name,
            backtrace: exception.backtrace.first(3)
          }
        )
      end
      
      def log_operation_success(operation_name)
        return unless ENV['FILEBOT_LOG_LEVEL'] == 'DEBUG'
        puts "[FileBot] SUCCESS: #{operation_name} at #{Time.now.strftime('%H:%M:%S')}"
      end
      
      def log_operation_error(operation_name, error, retry_count)
        return unless ENV['FILEBOT_LOG_LEVEL'] && ENV['FILEBOT_LOG_LEVEL'] != 'NONE'
        puts "[FileBot] ERROR: #{operation_name} failed (attempt #{retry_count}): #{error.message}"
      end
      
      def log_global_operation(operation_type, global, args, success)
        return unless ENV['FILEBOT_LOG_LEVEL'] == 'DEBUG'
        status = success ? 'SUCCESS' : 'FAILED'
        args_str = args.empty? ? '' : "(#{args.join(',')})"
        puts "[FileBot] #{status}: #{operation_type} #{global}#{args_str}"
      end
      
      def log_healthcare_error(operation_name, ien, error)
        return unless ENV['FILEBOT_LOG_LEVEL'] && ENV['FILEBOT_LOG_LEVEL'] != 'NONE'
        puts "[FileBot] HEALTHCARE ERROR: #{operation_name} for patient #{ien}: #{error.message}"
        
        # In production, this would go to a proper logging system
        if ENV['FILEBOT_LOG_LEVEL'] == 'DEBUG'
          puts "[FileBot] ERROR DETAILS: #{error.to_hash.to_json}" if error.respond_to?(:to_hash)
        end
      end
      
      public

      # FileBot no longer executes MUMPS/ObjectScript code
      # All business logic is now implemented in Ruby
      # IRIS is used as pure data layer only
      
      # Real ObjectScript/MUMPS execution using IRIS Native SDK
      def execute_mumps(mumps_code)
        return "" if @iris_native.nil?
        
        begin
          # Use IRIS Native SDK to execute ObjectScript directly
          # This bypasses SQL and executes real MUMPS/ObjectScript code
          result = @iris_native.classMethodValue("%SYSTEM.Process", "Evaluate", mumps_code)
          result.toString
        rescue => e
          puts "FileBot: ObjectScript execution failed: #{e.message}" if ENV['FILEBOT_DEBUG']
          # Fallback: try direct routine execution if available
          begin
            # Alternative: use procedure call for FileMan routines
            @iris_native.procedure("FileManCall", mumps_code)
          rescue => e2
            puts "FileBot: Fallback execution failed: #{e2.message}" if ENV['FILEBOT_DEBUG']
            ""
          end
        end
      end
      
      private
      
      # Helper methods for IRIS global operations
      
      public

      def lock_global(global, *subscripts, timeout: 30)
        lock_ref = build_lock_reference(global, *subscripts)
        @iris_native.lock(lock_ref, timeout) == 1
      rescue => e
        puts "Lock failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        false
      end

      def unlock_global(global, *subscripts)
        lock_ref = build_lock_reference(global, *subscripts)
        @iris_native.unlock(lock_ref)
        true
      rescue => e
        puts "Unlock failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        false
      end

      def start_transaction
        @iris_native.startTransaction
      rescue => e
        puts "Transaction start failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        nil
      end

      def commit_transaction(transaction)
        @iris_native.commitTransaction(transaction)
        true
      rescue => e
        puts "Transaction commit failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        false
      end

      def rollback_transaction(transaction)
        @iris_native.rollbackTransaction(transaction)
        true
      rescue => e
        puts "Transaction rollback failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        false
      end

      private

      # Override setup_connection from BaseAdapter
      def setup_connection
        setup_native_connection
      end

      def setup_native_connection
        require "java"

        # Load IRIS JARs using the JAR manager
        FileBot::JarManager.load_iris_jars!

        # Import IRIS classes for Native SDK (not just JDBC)
        java_import "com.intersystems.jdbc.IRISDriver"
        java_import "com.intersystems.jdbc.IRISConnection"
        java_import "com.intersystems.jdbc.IRIS"  # Native SDK class
        java_import "java.util.Properties"

        puts "FileBot: Establishing IRIS Native SDK connection" if ENV['FILEBOT_DEBUG']

        # Get credentials from environment configuration
        iris_config = get_iris_credentials

        # Step 1: Create JDBC connection (required for Native SDK)
        driver = IRISDriver.new
        properties = Properties.new
        properties.setProperty("user", iris_config[:username])
        properties.setProperty("password", iris_config[:password])

        connection_url = "jdbc:IRIS://#{iris_config[:host]}:#{iris_config[:port]}/#{iris_config[:namespace]}"
        @jdbc_connection = driver.connect(connection_url, properties)
        
        # Step 2: Create Native SDK object from JDBC connection
        @iris_native = IRIS.createIRIS(@jdbc_connection)

        puts "FileBot: IRIS Native SDK connection established to #{iris_config[:host]}:#{iris_config[:port]}" if ENV['FILEBOT_DEBUG']
        puts "FileBot: Native SDK object: #{@iris_native.class.name}" if ENV['FILEBOT_DEBUG']
      end

      def get_iris_credentials
        # Use centralized credentials manager
        FileBot::CredentialsManager.iris_config
      end

      def iris_version
        return @iris_version if defined?(@iris_version)
        
        begin
          # Try to get version from JDBC connection metadata
          if @iris_native
            metadata = @iris_native.getMetaData
            @iris_version = "#{metadata.getDatabaseProductName} #{metadata.getDatabaseProductVersion}"
          else
            @iris_version = "unknown"
          end
        rescue => e
          puts "Could not get IRIS version: #{e.message}" if ENV['FILEBOT_DEBUG']
          @iris_version = "unknown"
        end
        
        @iris_version
      end

      def build_lock_reference(global, *subscripts)
        ref = global.dup
        subscripts.each { |sub| ref << "(\"#{sub}\")" } unless subscripts.empty?
        ref
      end
    end
  end
end
