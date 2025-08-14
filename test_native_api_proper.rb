#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'

puts "🚀 IRIS Native API - Proper Implementation Test"
puts "=" * 50

ENV['FILEBOT_DEBUG'] = '1'

begin
  require "java"
  
  # Load IRIS JARs
  FileBot::JarManager.load_iris_jars!
  
  # Import both JDBC and Native API classes
  java_import "com.intersystems.jdbc.IRISDriver"
  java_import "com.intersystems.jdbc.IRISConnection"
  java_import "java.util.Properties"
  
  puts "1. Establishing JDBC connection..."
  driver = IRISDriver.new
  properties = Properties.new
  properties.setProperty("user", "_SYSTEM")
  properties.setProperty("password", "passwordpassword")
  
  connection_url = "jdbc:IRIS://localhost:1972/USER"
  jdbc_connection = driver.connect(connection_url, properties)
  puts "   ✅ JDBC connected: #{jdbc_connection.class.name}"
  
  puts "\n2. Creating IRIS Native API object using createIris()..."
  begin
    # This is the key method mentioned in documentation!
    iris_native = jdbc_connection.createIris
    puts "   ✅ Native API created: #{iris_native.class.name}"
    puts "   Native object: #{iris_native.inspect}"
    
    # Check available methods on the proper native API object
    puts "\n   Available methods on native IRIS object:"
    native_methods = iris_native.java_class.declared_instance_methods.map(&:name).sort
    
    # Look for the documented function methods
    function_methods = native_methods.select { |m| 
      m.include?('function') || m.include?('classMethod') || m.include?('procedure')
    }
    
    puts "   Function/Method execution methods:"
    function_methods.each { |m| puts "     • #{m}" }
    
    puts "\n3. Testing ObjectScript function calls..."
    
    # Test 1: functionString for simple expressions
    if iris_native.respond_to?(:functionString)
      puts "   Testing functionString with $HOROLOG..."
      begin
        result = iris_native.functionString("$HOROLOG")
        puts "   ✅ $HOROLOG result: #{result}"
      rescue => e
        puts "   ❌ functionString failed: #{e.message}"
      end
    else
      puts "   ❌ functionString method not available"
    end
    
    # Test 2: Create a simple ObjectScript wrapper class for global operations
    puts "\n4. Creating ObjectScript wrapper class for global operations..."
    begin
      # First try to create a simple test class in ObjectScript
      create_class_code = """
      Class FileBot.GlobalOps Extends %RegisteredObject
      {
      ClassMethod GetGlobal(global As %String, subscripts As %String = \"\") As %String
      {
          if subscripts = \"\" {
              return $GET(@global)
          } else {
              return $GET(@(global_\"(\"_subscripts_\")\"))
          }
      }
      
      ClassMethod SetGlobal(global As %String, subscripts As %String = \"\", value As %String = \"\") As %String
      {
          if subscripts = \"\" {
              set @global = value
          } else {
              set @(global_\"(\"_subscripts_\")\") = value
          }
          return \"OK\"
      }
      }
      """
      
      # Try to compile and create this class using classMethodVoid
      if iris_native.respond_to?(:classMethodVoid)
        puts "   Attempting to create ObjectScript wrapper class..."
        iris_native.classMethodVoid("%Compiler.UDL", "TextServices", create_class_code)
        puts "   ✅ Wrapper class creation attempted"
        
        # Test using our wrapper class
        puts "\n5. Testing global operations via wrapper class..."
        
        # Set a global value
        result = iris_native.classMethodString("FileBot.GlobalOps", "SetGlobal", "^TEST", "\"KEY\"", "TestValue")
        puts "   ✅ SetGlobal result: #{result}"
        
        # Get the global value back
        result = iris_native.classMethodString("FileBot.GlobalOps", "GetGlobal", "^TEST", "\"KEY\"")
        puts "   ✅ GetGlobal result: #{result}"
        
      else
        puts "   ❌ classMethodVoid not available for class creation"
      end
      
    rescue => e
      puts "   ❌ Wrapper class approach failed: #{e.message}"
    end
    
  rescue => e
    puts "   ❌ Failed to create native API: #{e.message}"
    puts "   Available methods on JDBC connection:"
    jdbc_methods = jdbc_connection.java_class.declared_instance_methods.map(&:name).sort
    create_methods = jdbc_methods.select { |m| m.downcase.include?('create') || m.downcase.include?('iris') }
    create_methods.each { |m| puts "     • #{m}" }
  end
  
  jdbc_connection.close
  
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts "Backtrace:"
  e.backtrace.first(5).each { |line| puts "  #{line}" }
end