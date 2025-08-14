#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'

puts "🔍 IRIS Connection Method Investigation"
puts "=" * 50

ENV['FILEBOT_DEBUG'] = '1'

begin
  adapter = FileBot::Adapters::IRISAdapter.new({})
  iris_conn = adapter.instance_variable_get(:@iris_native)
  
  puts "Connection class: #{iris_conn.class.name}"
  puts "Connection object: #{iris_conn.inspect}"
  
  puts "\n📋 Available Methods on IRISConnection:"
  puts "-" * 40
  
  # Get all methods and filter for interesting ones
  all_methods = iris_conn.java_class.declared_instance_methods.map(&:name).sort
  
  interesting_methods = all_methods.select do |method|
    method.downcase.include?('exec') ||
    method.downcase.include?('mumps') ||
    method.downcase.include?('iris') ||
    method.downcase.include?('native') ||
    method.downcase.include?('global') ||
    method.downcase.include?('script')
  end
  
  puts "Execution-related methods:"
  interesting_methods.each { |method| puts "  • #{method}" }
  
  puts "\nAll available methods (first 30):"
  all_methods.first(30).each { |method| puts "  • #{method}" }
  
  puts "\n🧪 Testing Available Execution Methods:"
  puts "-" * 40
  
  # Test 1: createIris (mentioned in previous conversation)  
  if iris_conn.respond_to?(:createIris)
    puts "1. Testing createIris() method..."
    begin
      iris_native = iris_conn.createIris
      puts "   ✅ createIris returned: #{iris_native.class.name}"
      puts "   Available methods on native object:"
      native_methods = iris_native.java_class.declared_instance_methods.map(&:name).sort
      exec_methods = native_methods.select { |m| m.downcase.include?('exec') || m.downcase.include?('run') }
      exec_methods.each { |m| puts "     • #{m}" }
    rescue => e
      puts "   ❌ createIris failed: #{e.message}"
    end
  else
    puts "1. createIris method not available"
  end
  
  # Test 2: Check if there are any callable/procedure methods
  puts "\n2. Testing procedure call methods..."
  procedure_methods = all_methods.select { |m| m.downcase.include?('call') || m.downcase.include?('procedure') }
  puts "   Procedure methods: #{procedure_methods.join(', ')}"
  
  # Test 3: Look for createStatement variations
  puts "\n3. Testing statement variations..."
  statement_methods = all_methods.select { |m| m.downcase.include?('statement') }
  puts "   Statement methods: #{statement_methods.join(', ')}"
  
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts "Backtrace:"
  e.backtrace.first(5).each { |line| puts "  #{line}" }
end