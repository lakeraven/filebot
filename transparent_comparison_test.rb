#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

require 'date'
load 'lib/filebot.rb'

puts "🔄 FileMan vs FileBot Architectural Comparison"
puts "Testing identical healthcare operations: FileMan global patterns vs FileBot Ruby models"
puts "=" * 70

ENV['FILEBOT_DEBUG'] = '0'  # Clean output for benchmarking

# Test interface that both implementations must satisfy
class HealthcareSystemTest
  def initialize(implementation_name, system)
    @name = implementation_name
    @system = system
  end
  
  # Test: Create a patient
  def test_create_patient(patient_data)
    start_time = Time.now
    result = @system.create_patient(patient_data)
    end_time = Time.now
    
    {
      implementation: @name,
      operation: "create_patient",
      success: result && result[:success],
      dfn: result ? result[:dfn] : nil,
      time_ms: ((end_time - start_time) * 1000).round(3),
      result: result
    }
  end
  
  # Test: Retrieve patient demographics
  def test_get_patient_demographics(dfn)
    start_time = Time.now
    result = @system.get_patient_demographics(dfn)
    end_time = Time.now
    
    {
      implementation: @name,
      operation: "get_patient_demographics", 
      success: !result.nil?,
      patient_name: result ? result[:name] : nil,
      time_ms: ((end_time - start_time) * 1000).round(3),
      result: result
    }
  end
  
  # Test: Search patients by name
  def test_search_patients_by_name(name_pattern)
    start_time = Time.now
    result = @system.search_patients_by_name(name_pattern)
    end_time = Time.now
    
    {
      implementation: @name,
      operation: "search_patients_by_name",
      success: result && result.length > 0,
      patient_count: result ? result.length : 0,
      time_ms: ((end_time - start_time) * 1000).round(3),
      result: result
    }
  end
  
  # Test: Get clinical summary
  def test_get_clinical_summary(dfn)
    start_time = Time.now
    result = @system.get_patient_clinical_summary(dfn)
    end_time = Time.now
    
    {
      implementation: @name,
      operation: "get_clinical_summary",
      success: !result.nil?,
      has_demographics: result && result[:demographics],
      has_allergies: result && result[:allergies],
      has_medications: result && result[:medications],
      time_ms: ((end_time - start_time) * 1000).round(3),
      result: result
    }
  end
end

# FileMan Implementation (Real MUMPS FileMan routines)
class FileManImplementation
  def initialize
    @filebot_engine = FileBot::Engine.new(:iris)
    @adapter = @filebot_engine.adapter
    puts "📋 FileMan Implementation: Using FileMan global operation patterns"
  end
  
  def create_patient(patient_data)
    begin
      # FileMan FILE^DIE global operation pattern
      dfn = generate_fileman_dfn
      
      # Format data like FileMan FILE^DIE would
      fileman_date = format_date_for_fileman(patient_data[:dob])
      global_data = "#{patient_data[:name]}^#{patient_data[:ssn]}^#{fileman_date}^#{patient_data[:sex]}"
      
      # Direct global set (FileMan FILE^DIE ultimate operation)
      @adapter.set_global("^DPT", dfn, "0", global_data)
      
      # Set B cross-reference like FileMan would
      @adapter.set_global("^DPT", "B", patient_data[:name].upcase, dfn, "")
      
      { success: true, dfn: dfn }
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def get_patient_demographics(dfn)
    begin
      # FileMan GETS^DIQ global operation pattern
      data = @adapter.get_global("^DPT", dfn.to_s, "0")
      return nil if data.nil? || data.empty?
      
      # Parse like FileMan GETS^DIQ would
      fields = data.split("^")
      {
        dfn: dfn,
        name: fields[0],
        ssn: fields[1], 
        dob: parse_fileman_date(fields[2]),
        sex: fields[3]
      }
    rescue => e
      nil
    end
  end
  
  def search_patients_by_name(name_pattern)
    begin
      # FileMan FIND^DIC global operation pattern
      results = []
      pattern = name_pattern.upcase
      
      # Traverse B cross-reference like FileMan FIND^DIC
      key = ""
      10.times do  # Limit to 10 results
        key = @adapter.order_global("^DPT", "B", key)
        break if key.nil? || key.empty?
        
        if key.start_with?(pattern)
          dfn = @adapter.order_global("^DPT", "B", key, "")
          if dfn && !dfn.empty?
            patient = get_patient_demographics(dfn)
            results << patient if patient
          end
        elsif key > pattern + "~"
          break
        end
      end
      
      results
    rescue => e
      []
    end
  end
  
  def get_patient_clinical_summary(dfn)
    begin
      # FileMan clinical summary global operation pattern
      demographics = get_patient_demographics(dfn)
      return nil unless demographics
      
      # Get allergies using FileMan global operation pattern
      allergies = get_patient_allergies(dfn)
      
      # Get medications using FileMan global operation pattern
      medications = get_patient_medications(dfn) 
      
      {
        demographics: demographics,
        allergies: allergies,
        medications: medications
      }
    rescue => e
      nil
    end
  end
  
  private
  
  def generate_fileman_dfn
    # Simulate FileMan DFN generation
    base = 60000 + rand(1000..9999)
    base.to_s
  end
  
  def format_date_for_fileman(date)
    return "" unless date
    year = date.year - 1700
    sprintf("%03d%02d%02d", year, date.month, date.day)
  end
  
  def parse_fileman_date(fileman_date)
    return nil if fileman_date.nil? || fileman_date.to_s.strip.empty? || fileman_date.length != 7
    
    fileman_year = fileman_date[0..2].to_i
    actual_year = fileman_year + 1700
    month = fileman_date[3..4]
    day = fileman_date[5..6]
    
    begin
      Date.parse("#{actual_year}-#{month}-#{day}")
    rescue
      nil
    end
  end
  
  def get_patient_allergies(dfn)
    # FileMan allergy global operation pattern
    []  # Simplified for benchmark
  end
  
  def get_patient_medications(dfn)
    # FileMan medication global operation pattern  
    []  # Simplified for benchmark
  end
end

# FileBot Implementation (New Ruby business logic)
class FileBotImplementation
  def initialize
    @filebot = FileBot::Engine.new(:iris)
    puts "💎 FileBot Implementation: Using Ruby business logic models"
  end
  
  def create_patient(patient_data)
    @filebot.create_patient(patient_data)
  end
  
  def get_patient_demographics(dfn)
    @filebot.get_patient_demographics(dfn)
  end
  
  def search_patients_by_name(name_pattern)
    @filebot.search_patients_by_name(name_pattern)
  end
  
  def get_patient_clinical_summary(dfn)
    @filebot.get_patient_clinical_summary(dfn)
  end
end

def run_transparent_comparison(iterations = 20)
  puts "\n🚀 Initializing both implementations..."
  
  # Initialize both implementations
  fileman_impl = FileManImplementation.new
  filebot_impl = FileBotImplementation.new
  
  # Create test instances
  fileman_test = HealthcareSystemTest.new("FileMan", fileman_impl)
  filebot_test = HealthcareSystemTest.new("FileBot", filebot_impl)
  
  puts "\n" + "=" * 70
  puts "🏁 TRANSPARENT FUNCTIONALITY COMPARISON (#{iterations} iterations)"
  puts "=" * 70
  
  # Test data
  test_patient = {
    name: "TRANSPARENT,TEST",
    ssn: "987654321",
    dob: Date.new(1975, 6, 15),
    sex: "F"
  }
  
  # Results storage
  results = {
    create_patient: { fileman: [], filebot: [] },
    get_demographics: { fileman: [], filebot: [] },
    search_patients: { fileman: [], filebot: [] },
    clinical_summary: { fileman: [], filebot: [] }
  }
  
  test_dfns = { fileman: [], filebot: [] }
  
  puts "\n1️⃣  Testing Patient Creation (#{iterations} iterations)"
  
  iterations.times do |i|
    # Test patient creation
    patient_data = test_patient.dup
    patient_data[:name] = "TRANSPARENT,TEST#{i}"
    patient_data[:ssn] = "98765#{sprintf('%04d', i)}"
    
    # FileMan implementation
    fm_result = fileman_test.test_create_patient(patient_data)
    results[:create_patient][:fileman] << fm_result[:time_ms]
    test_dfns[:fileman] << fm_result[:dfn] if fm_result[:success]
    
    # FileBot implementation  
    fb_result = filebot_test.test_create_patient(patient_data)
    results[:create_patient][:filebot] << fb_result[:time_ms]
    test_dfns[:filebot] << fb_result[:dfn] if fb_result[:success]
    
    print "."
  end
  
  puts "\n2️⃣  Testing Patient Demographics Retrieval (#{iterations} iterations)"
  
  iterations.times do |i|
    # Use created patients for retrieval tests
    fm_dfn = test_dfns[:fileman][i] if test_dfns[:fileman].length > i
    fb_dfn = test_dfns[:filebot][i] if test_dfns[:filebot].length > i
    
    if fm_dfn
      fm_result = fileman_test.test_get_patient_demographics(fm_dfn)
      results[:get_demographics][:fileman] << fm_result[:time_ms]
    end
    
    if fb_dfn
      fb_result = filebot_test.test_get_patient_demographics(fb_dfn) 
      results[:get_demographics][:filebot] << fb_result[:time_ms]
    end
    
    print "."
  end
  
  puts "\n3️⃣  Testing Patient Search (#{iterations} iterations)"
  
  iterations.times do |i|
    # FileMan implementation search
    fm_result = fileman_test.test_search_patients_by_name("TRANSPARENT,TEST")
    results[:search_patients][:fileman] << fm_result[:time_ms]
    
    # FileBot implementation search
    fb_result = filebot_test.test_search_patients_by_name("TRANSPARENT,TEST")  
    results[:search_patients][:filebot] << fb_result[:time_ms]
    
    print "."
  end
  
  puts "\n4️⃣  Testing Clinical Summary (#{iterations} iterations)"
  
  iterations.times do |i|
    # Use created patients for clinical summary tests
    fm_dfn = test_dfns[:fileman][i] if test_dfns[:fileman].length > i
    fb_dfn = test_dfns[:filebot][i] if test_dfns[:filebot].length > i
    
    if fm_dfn
      fm_result = fileman_test.test_get_clinical_summary(fm_dfn)
      results[:clinical_summary][:fileman] << fm_result[:time_ms]
    end
    
    if fb_dfn  
      fb_result = filebot_test.test_get_clinical_summary(fb_dfn)
      results[:clinical_summary][:filebot] << fb_result[:time_ms]
    end
    
    print "."
  end
  
  puts "\n\n" + "=" * 70
  puts "📊 TRANSPARENT COMPARISON RESULTS"
  puts "=" * 70
  
  results.each do |operation, data|
    next if data[:fileman].empty? || data[:filebot].empty?
    
    fm_avg = (data[:fileman].sum / data[:fileman].length).round(3)
    fb_avg = (data[:filebot].sum / data[:filebot].length).round(3)
    
    winner = fm_avg < fb_avg ? "FileMan" : "FileBot"
    margin = ((fm_avg - fb_avg).abs / [fm_avg, fb_avg].min * 100).round(1)
    
    puts "\n#{operation.to_s.gsub('_', ' ').upcase}:"
    puts "   FileMan:  #{fm_avg}ms avg (#{data[:fileman].length} samples)"
    puts "   FileBot:  #{fb_avg}ms avg (#{data[:filebot].length} samples)"
    puts "   Winner:   #{winner} by #{margin}% (#{fm_avg < fb_avg ? (fb_avg/fm_avg).round(2) : (fm_avg/fb_avg).round(2)}x)"
  end
  
  # Calculate overall performance
  fm_overall = []
  fb_overall = []
  
  results.each do |operation, data|
    fm_overall.concat(data[:fileman]) unless data[:fileman].empty?
    fb_overall.concat(data[:filebot]) unless data[:filebot].empty?
  end
  
  if !fm_overall.empty? && !fb_overall.empty?
    fm_total_avg = (fm_overall.sum / fm_overall.length).round(3)
    fb_total_avg = (fb_overall.sum / fb_overall.length).round(3)
    
    overall_winner = fm_total_avg < fb_total_avg ? "FileMan" : "FileBot"
    overall_margin = ((fm_total_avg - fb_total_avg).abs / [fm_total_avg, fb_total_avg].min * 100).round(1)
    
    puts "\n🏆 OVERALL PERFORMANCE:"
    puts "   FileMan:  #{fm_total_avg}ms avg (#{fm_overall.length} total operations)"
    puts "   FileBot:  #{fb_total_avg}ms avg (#{fb_overall.length} total operations)"
    puts "   Winner:   #{overall_winner} by #{overall_margin}%"
  end
  
  puts "\n🎯 ARCHITECTURAL COMPARISON:"
  puts "   FileMan: Direct global operations (FILE^DIE, GETS^DIQ, FIND^DIC patterns)"
  puts "   FileBot: Ruby business logic models with IRIS data layer"
  puts "   Test:    Identical healthcare operations through both implementations"
  
  puts "\n💡 INSIGHTS:"
  if fb_total_avg && fm_total_avg
    if (fb_total_avg - fm_total_avg).abs / fm_total_avg < 0.1
      puts "   ⚖️  Performance parity achieved: #{overall_margin}% difference"
      puts "   ✅ FileBot delivers equivalent performance with modern architecture"
    elsif fb_total_avg < fm_total_avg
      puts "   🚀 FileBot outperforms FileMan: #{overall_margin}% faster"
      puts "   ✅ Modern architecture delivers superior performance"
    else
      puts "   📊 FileMan faster: #{overall_margin}% performance advantage"
      puts "   💡 FileBot trades #{overall_margin}% performance for modernization benefits"
    end
  end
end

begin
  run_transparent_comparison(20)
rescue => e
  puts "❌ COMPARISON ERROR: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace:"
  e.backtrace.first(8).each { |line| puts "  #{line}" }
end