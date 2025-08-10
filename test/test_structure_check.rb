#!/usr/bin/env jruby

# Check that all test files have valid Ruby syntax
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'filebot'

puts "🧪 FileBot Test Structure Check"
puts "=" * 40

# List all test files
test_files = [
  'test/database_operations_test.rb',
  'test/pointer_fields_test.rb', 
  'test/advanced_fields_test.rb',
  'test/filebot_core_test.rb',
  'test/healthcare_validator_test.rb',
  'test/data_dictionary_test.rb',
  'test/cross_reference_manager_test.rb',
  'test/validation_engine_test.rb',
  'test/business_rules_engine_test.rb',
  'test/field_definition_test.rb',
  'test/filebot_compatibility_test.rb',
  'test/integration_test.rb'
]

puts "📁 Checking test file syntax:"

syntax_errors = 0
total_files = 0

test_files.each do |file_path|
  if File.exist?(file_path)
    total_files += 1
    print "  #{File.basename(file_path)}... "
    
    begin
      # Check Ruby syntax without executing
      result = `jruby -c #{file_path} 2>&1`
      
      if result.include?("Syntax OK") || result.empty?
        puts "✅ Valid"
      else
        puts "❌ Syntax Error"
        puts "    #{result.strip}"
        syntax_errors += 1
      end
    rescue => e
      puts "❌ Check Failed"
      puts "    #{e.message}"
      syntax_errors += 1
    end
  else
    puts "  #{File.basename(file_path)}... ⚠️  Not Found"
  end
end

# Check test method patterns
puts "\n🔍 Checking test method patterns:"

test_method_patterns = [
  /test "[^"]+"/,  # RSpec/minitest style: test "description"
  /def test_\w+/,  # Traditional style: def test_method_name
]

pattern_matches = 0

test_files.each do |file_path|
  if File.exist?(file_path)
    content = File.read(file_path)
    
    test_method_patterns.each do |pattern|
      matches = content.scan(pattern).length
      if matches > 0
        pattern_matches += matches
      end
    end
  end
end

puts "  Found #{pattern_matches} test methods across #{total_files} files"

# Check required test patterns
puts "\n📋 Checking test coverage patterns:"

coverage_patterns = [
  { name: "Database Operations", pattern: /test.*database|find_entries|list_entries|delete_entry/ },
  { name: "CRUD Operations", pattern: /test.*(create|read|update|delete|gets_entry)/ },
  { name: "Validation Tests", pattern: /test.*validat/ },
  { name: "Error Handling", pattern: /test.*(error|fail|exception)/ },
  { name: "Performance Tests", pattern: /test.*(performance|benchmark|speed)/ },
  { name: "Cross-Reference Tests", pattern: /test.*(cross|reference|index)/ },
  { name: "Pointer Field Tests", pattern: /test.*pointer/ },
  { name: "Healthcare Tests", pattern: /test.*(patient|healthcare|clinical)/ }
]

test_files.each do |file_path|
  if File.exist?(file_path)
    content = File.read(file_path)
    
    puts "\n  #{File.basename(file_path)}:"
    coverage_patterns.each do |pattern_info|
      matches = content.scan(pattern_info[:pattern]).length
      if matches > 0
        puts "    ✅ #{pattern_info[:name]} (#{matches} tests)"
      else
        puts "    ⚪ #{pattern_info[:name]} (not covered)"
      end
    end
  end
end

# Summary
puts "\n" + "=" * 40
puts "📊 Test Structure Summary:"
puts "   • Total test files: #{total_files}"
puts "   • Syntax errors: #{syntax_errors}"
puts "   • Test methods found: #{pattern_matches}"

if syntax_errors == 0
  puts "\n🎉 All test files have valid syntax!"
  puts "✅ Ready for execution when dependencies are available"
else
  puts "\n❌ #{syntax_errors} files have syntax errors"
  puts "   Fix syntax before running tests"
end

puts "\n💡 To run full test suite:"
puts "   1. Install dependencies: bundle install"
puts "   2. Set up IRIS connection"  
puts "   3. Run: bundle exec rake test"