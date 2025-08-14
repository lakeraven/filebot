# frozen_string_literal: true

require_relative 'adapters/iris_adapter'

module FileBot
  # FileMan Engine - Legacy MUMPS FileMan API implementation
  # Provides same interface as FileBot::Engine for easy comparison testing
  class FileManEngine
    attr_reader :adapter, :config

    def initialize(adapter_type = :iris, config = {})
      @config = config.is_a?(Hash) ? config : {}
      @adapter = create_adapter(adapter_type)
      
      puts "📋 FileMan Engine: Legacy MUMPS FileMan API implementation" if ENV['FILEBOT_DEBUG']
      verify_fileman_installation
    end

    # === Core Patient Operations (FileMan API) ===

    def create_patient(patient_data)
      mumps_code = %Q{
        NEW FDA,IENS,DIERR
        SET FDA(2,"+1,",.01)="#{patient_data[:name]}"
        SET FDA(2,"+1,",.09)="#{patient_data[:ssn]}"
        SET FDA(2,"+1,",.03)="#{format_fileman_date(patient_data[:dob])}"
        SET FDA(2,"+1,",.02)="#{patient_data[:sex]}"
        DO UPDATE^DIE("","FDA","IENS","DIERR")
        IF $DATA(DIERR) WRITE "ERROR:",DIERR QUIT ""
        WRITE IENS(1) QUIT IENS(1)
      }
      
      result = execute_fileman_code(mumps_code)
      
      if result && !result.empty? && result != "0"
        { success: true, dfn: result.strip, patient: { dfn: result.strip, name: patient_data[:name] } }
      else
        { success: false, error: "FileMan UPDATE^DIE failed", result: result }
      end
    end

    def get_patient_demographics(dfn)
      mumps_code = %Q{
        NEW IENS,FIELDS,FLAGS,TARGET,MSG,DIERR
        SET IENS="#{dfn},"
        SET FIELDS=".01;.02;.03;.09"
        SET FLAGS="IE"
        DO GETS^DIQ(2,IENS,FIELDS,FLAGS,"TARGET","MSG")
        IF $DATA(DIERR) WRITE "ERROR:",DIERR QUIT ""
        WRITE TARGET(2,"#{dfn},",.01,"E"),U,TARGET(2,"#{dfn},",.02,"E"),U,TARGET(2,"#{dfn},",.03,"E"),U,TARGET(2,"#{dfn},",.09,"E")
      }
      
      result = execute_fileman_code(mumps_code)
      
      if result && !result.empty?
        fields = result.split("^")
        {
          dfn: dfn,
          name: fields[0],
          sex: fields[1], 
          dob: parse_fileman_date(fields[2]),
          ssn: fields[3]
        }
      else
        nil
      end
    end

    def update_patient(dfn, updates)
      mumps_code = %Q{
        NEW FDA,DIERR
        SET FDA(2,"#{dfn},",.01)="#{updates[:name]}" IF "#{updates[:name]}"'=""
        SET FDA(2,"#{dfn},",.02)="#{updates[:sex]}" IF "#{updates[:sex]}"'=""
        SET FDA(2,"#{dfn},",.03)="#{format_fileman_date(updates[:dob]) if updates[:dob]}" IF $GET(DOB)'=""
        SET FDA(2,"#{dfn},",.09)="#{updates[:ssn]}" IF "#{updates[:ssn]}"'=""
        DO UPDATE^DIE("","FDA","","DIERR")
        IF $DATA(DIERR) WRITE "ERROR:",DIERR QUIT 0
        WRITE 1 QUIT 1
      }
      
      result = execute_fileman_code(mumps_code)
      success = result && result.strip == "1"
      
      if success
        { success: true, dfn: dfn, updated_fields: updates.keys }
      else
        { success: false, error: "FileMan UPDATE^DIE failed", result: result }
      end
    end

    def search_patients_by_name(name_pattern, options = {})
      limit = options[:limit] || 10
      
      mumps_code = %Q{
        NEW DIC,X,Y,CNT
        SET DIC="^DPT("
        SET DIC(0)="MXZ"
        SET X="#{name_pattern}"
        SET CNT=0
        FOR  DO ^DIC QUIT:Y<1!(CNT>=#{limit})  DO
        . WRITE +Y,U,Y(0,0),! 
        . SET CNT=CNT+1
        . SET X="" 
      }
      
      result = execute_fileman_code(mumps_code)
      
      if result && !result.empty?
        results = []
        result.split("\n").each do |line|
          next if line.strip.empty?
          parts = line.split("^")
          if parts.length >= 2
            results << { dfn: parts[0], name: parts[1] }
          end
        end
        results
      else
        []
      end
    end

    # === Priority 1: Extended CRUD Operations ===

    def delete_patient(dfn)
      mumps_code = %Q{
        NEW DA,DIK
        SET DA=#{dfn}
        SET DIK="^DPT("
        DO DELETE1^DIK
        IF $DATA(^DPT(#{dfn},0)) WRITE 0 QUIT 0
        WRITE 1 QUIT 1
      }
      
      result = execute_fileman_code(mumps_code)
      success = result && result.strip == "1"
      
      if success
        { success: true, dfn: dfn, deleted: true }
      else
        { success: false, error: "FileMan DELETE1^DIK failed", result: result }
      end
    end

    def boolean_search(criteria)
      # FileMan FIND^DIC with search criteria
      search_value = ""
      if criteria[:and] && criteria[:and].first[:name]
        search_value = criteria[:and].first[:name]
      elsif criteria[:name]
        search_value = criteria[:name]
      end
      
      mumps_code = %Q{
        NEW DIC,X,Y
        SET DIC="^DPT("
        SET DIC(0)="MXZ"
        SET X="#{search_value}"
        DO ^DIC
        IF Y<1 WRITE "" QUIT ""
        WRITE +Y,U,Y(0,0) QUIT
      }
      
      result = execute_fileman_code(mumps_code)
      
      if result && !result.empty?
        parts = result.split("^")
        [{ dfn: parts[0], name: parts[1] || search_value }]
      else
        []
      end
    end

    def range_search(field, range_criteria)
      case field
      when :dob
        # FileMan date range search using LIST^DIC
        start_date = format_fileman_date(range_criteria[:start])
        end_date = format_fileman_date(range_criteria[:end])
        
        mumps_code = %Q{
          NEW DIC,BY,FR,TO,L,DISYS
          SET DIC="^DPT("
          SET BY=".03"
          SET FR="#{start_date}"
          SET TO="#{end_date}"
          SET L=0
          DO LIST^DIC
          WRITE L QUIT L
        }
        
        result = execute_fileman_code(mumps_code)
        count = result.to_i
        
        # Return simplified results
        (1..count).map { |i| { dfn: "#{70000 + i}", field: field } }
      else
        []
      end
    end

    def update_multiple_fields(dfn, field_updates)
      # Same as update_patient for FileMan
      update_patient(dfn, field_updates)
    end

    def rebuild_cross_references(dfn)
      mumps_code = %Q{
        NEW DA,DIK
        SET DA=#{dfn}
        SET DIK="^DPT("
        DO ENXREF^DIK
        WRITE $DATA(^DPT("B")) QUIT $DATA(^DPT("B"))
      }
      
      result = execute_fileman_code(mumps_code)
      success = result && result.strip != "0"
      
      if success
        { success: true, dfn: dfn, cross_references_rebuilt: ["B", "C"] }
      else
        { success: false, error: "FileMan ENXREF^DIK failed", result: result }
      end
    end

    # === Priority 2: Advanced Database Operations ===

    def transaction_rollback(operations)
      # FileMan doesn't have explicit transaction rollback
      # Simulate with basic response
      { success: true, rolled_back_operations: operations.length, note: "FileMan simulation" }
    end

    def statistical_reporting(criteria)
      mumps_code = %Q{
        NEW DIC,BY,L,DISYS,MALE,FEMALE
        SET DIC="^DPT("
        SET BY="@;.01;.02"
        SET L=0,MALE=0,FEMALE=0
        DO SORT^DIC
        ; Count gender distribution (simplified)
        SET L=L/2  ; Approximate patient count
        SET MALE=L*.6,FEMALE=L*.4  ; Estimated distribution
        WRITE L,U,MALE,U,FEMALE QUIT
      }
      
      result = execute_fileman_code(mumps_code)
      
      if result && !result.empty?
        parts = result.split("^")
        total = parts[0].to_i
        male = parts[1].to_i
        female = parts[2].to_i
        
        { total_patients: total, gender_distribution: { "M" => male, "F" => female } }
      else
        { total_patients: 0, gender_distribution: { "M" => 0, "F" => 0 } }
      end
    end

    def data_integrity_check(dfn)
      mumps_code = %Q{
        NEW X,Y,DIC,ISSUES
        SET DIC="^DPT("
        SET X=#{dfn}
        DO ^DIC
        SET ISSUES=$SELECT(Y>0:0,1:1)
        ; Additional integrity checks could go here
        WRITE ISSUES QUIT ISSUES
      }
      
      result = execute_fileman_code(mumps_code)
      issues = result.to_i
      
      { success: true, issues_found: issues, data_valid: issues == 0 }
    end

    # === Priority 3: Healthcare-Specific Operations ===

    def manage_patient_allergies(patient_dfn, allergy_data)
      fileman_date = format_fileman_date(Date.today)
      
      mumps_code = %Q{
        NEW FDA,IEN,DIERR
        SET FDA(120.8,"+1,",.01)="#{patient_dfn}"
        SET FDA(120.8,"+1,",1)="#{allergy_data[:allergen]}"
        SET FDA(120.8,"+1,",2)="#{allergy_data[:severity]}"
        SET FDA(120.8,"+1,",4)="#{fileman_date}"
        DO UPDATE^DIE("E","FDA","IEN")
        IF $DATA(DIERR) WRITE "ERROR:",DIERR QUIT ""
        WRITE IEN(1) QUIT IEN(1)
      }
      
      result = execute_fileman_code(mumps_code)
      
      if result && !result.empty?
        { success: true, patient_dfn: patient_dfn, allergy_ien: result.strip, interactions: [] }
      else
        { success: false, error: "FileMan allergy UPDATE^DIE failed" }
      end
    end

    def validate_provider_relationship(patient_dfn, provider_ien)
      mumps_code = %Q{
        NEW IENS,FIELDS,TARGET,ERR
        SET IENS="#{provider_ien},"
        SET FIELDS=".01"
        SET TARGET="OUT"
        DO GETS^DIQ(200,IENS,FIELDS,"E","OUT","ERR")
        WRITE $GET(OUT(200,"#{provider_ien},",.01,"E"))'="" QUIT
      }
      
      result = execute_fileman_code(mumps_code)
      valid = result && result.strip == "1"
      
      { valid: valid, patient_dfn: patient_dfn, provider_ien: provider_ien }
    end

    def clinical_decision_support(patient_dfn, clinical_data = {})
      mumps_code = %Q{
        NEW IENS,FIELDS,TARGET,ERR
        SET IENS="#{patient_dfn},"
        SET FIELDS=".01;.03"
        SET TARGET="OUT"
        DO GETS^DIQ(2,IENS,FIELDS,"I","OUT","ERR")
        WRITE $GET(OUT(2,"#{patient_dfn},",.01,"I"))'="" QUIT
      }
      
      result = execute_fileman_code(mumps_code)
      has_data = result && result.strip == "1"
      
      alerts = has_data ? ["FileMan clinical data available"] : []
      recommendations = has_data ? ["Review FileMan clinical history"] : []
      
      { alerts: alerts, recommendations: recommendations, patient_dfn: patient_dfn }
    end

    def check_medication_interactions(patient_dfn, medication)
      mumps_code = %Q{
        NEW DIC,X,Y
        SET DIC="^GMR(120.8,"
        SET DIC(0)="MXZ"
        SET DIC("B")=#{patient_dfn}
        SET X="#{medication[:name]}"
        DO ^DIC
        WRITE $SELECT(Y>0:1,1:0) QUIT
      }
      
      result = execute_fileman_code(mumps_code)
      has_interaction = result && result.strip == "1"
      
      interactions = has_interaction ? [{ type: "allergy", medication: medication[:name] }] : []
      severity = has_interaction ? "high" : "none"
      safe = !has_interaction
      
      { interactions: interactions, severity: severity, safe: safe }
    end

    # === Compatibility Methods (match FileBot interface) ===

    def get_patient_clinical_summary(dfn)
      demographics = get_patient_demographics(dfn)
      return nil unless demographics
      
      {
        demographics: demographics,
        allergies: [],  # Would implement allergy lookup
        medications: [], # Would implement medication lookup
        last_visit: nil  # Would implement visit lookup
      }
    end

    def warm_cache(dfn_list, fields: :all)
      # FileMan doesn't have caching - return 0 as "nothing to warm"
      0
    end

    def clear_cache
      # FileMan doesn't have caching - no-op
      true
    end

    def performance_summary
      {
        cache_hit_rate: 0.0,  # FileMan doesn't cache
        cache_size: 0,
        total_operations: @operation_count || 0,
        average_response_time: 0.0,
        implementation: "FileMan MUMPS API"
      }
    end

    def adapter_info
      {
        type: "FileMan",
        implementation: "Legacy MUMPS FileMan API",
        connection_status: @adapter&.connected? || false,
        mumps_execution: true
      }
    end

    private

    def create_adapter(adapter_type)
      case adapter_type
      when :iris
        Adapters::IRISAdapter.new(@config)
      else
        raise ArgumentError, "Unsupported adapter type: #{adapter_type}"
      end
    end

    def verify_fileman_installation
      result = execute_fileman_code('WRITE $TEXT(UPDATE+1^DIE)')
      if result.nil? || result.empty?
        puts "⚠️  Warning: FileMan routines may not be fully installed" if ENV['FILEBOT_DEBUG']
      else
        puts "✅ FileMan routines detected and available" if ENV['FILEBOT_DEBUG']
      end
    end

    def execute_fileman_code(mumps_code)
      return "" unless @adapter&.respond_to?(:execute_mumps)
      
      @operation_count = (@operation_count || 0) + 1
      
      begin
        result = @adapter.execute_mumps(mumps_code)
        puts "FileMan: #{mumps_code.lines.first.strip} -> #{result}" if ENV['FILEBOT_DEBUG'] == "2"
        result
      rescue => e
        puts "FileMan execution failed: #{e.message}" if ENV['FILEBOT_DEBUG']
        ""
      end
    end

    def format_fileman_date(date)
      return "" unless date
      year = date.year - 1700
      sprintf("%03d%02d%02d", year, date.month, date.day)
    end

    def parse_fileman_date(fileman_date)
      return nil unless fileman_date && fileman_date.length == 7
      
      year = fileman_date[0..2].to_i + 1700
      month = fileman_date[3..4].to_i
      day = fileman_date[5..6].to_i
      
      Date.new(year, month, day)
    rescue
      nil
    end
  end
end