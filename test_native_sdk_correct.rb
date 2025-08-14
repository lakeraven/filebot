#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'

puts "🎯 IRIS Native SDK - Correct Implementation"
puts "=" * 45

ENV['FILEBOT_DEBUG'] = '1'

begin
  require "java"
  
  # Load IRIS JARs
  FileBot::JarManager.load_iris_jars!
  
  # Import the correct classes based on documentation
  java_import "com.intersystems.jdbc.IRISConnection"
  java_import "com.intersystems.jdbc.IRIS"  # This should contain createIRIS method
  java_import "java.sql.DriverManager"
  
  puts "1. Creating JDBC connection using DriverManager pattern..."
  begin
    conn_str = "jdbc:IRIS://localhost:1972/USER"
    user = "_SYSTEM"
    password = "passwordpassword"
    
    # Use DriverManager as shown in documentation
    connection = DriverManager.getConnection(conn_str, user, password)
    puts "   ✅ JDBC Connection: #{connection.class.name}"
    
    # Cast to IRISConnection as shown in docs
    iris_conn = connection
    puts "   ✅ IRISConnection: #{iris_conn.class.name}"
    
  rescue => e
    puts "   ❌ Connection failed: #{e.message}"
    raise
  end
  
  puts "\n2. Creating IRIS Native SDK object using IRIS.createIRIS()..."
  begin
    # This is the key method from documentation: IRIS.createIRIS(conn)
    iris_native = IRIS.createIRIS(iris_conn)
    puts "   ✅ Native SDK created: #{iris_native.class.name}"
    puts "   Native object: #{iris_native.inspect}"
    
    # Check available methods
    puts "\n   Available methods on IRIS Native SDK:"
    native_methods = iris_native.java_class.declared_instance_methods.map(&:name).sort
    
    # Look for the key methods mentioned in documentation
    key_methods = native_methods.select { |m| 
      m.include?('set') || m.include?('get') || m.include?('function') || 
      m.include?('classMethod') || m.include?('getString')
    }
    
    puts "   Key native methods:"
    key_methods.first(15).each { |m| puts "     • #{m}" }
    
  rescue => e
    puts "   ❌ Native SDK creation failed: #{e.message}"
    puts "   Available classes in JDBC package:"
    
    # Check what IRIS classes are available
    begin
      java_classes = ["IRIS", "IRISConnection", "IRISDriver"]
      java_classes.each do |cls_name|
        begin
          java_import "com.intersystems.jdbc.#{cls_name}"
          puts "     ✅ #{cls_name} available"
        rescue => import_error
          puts "     ❌ #{cls_name} not available: #{import_error.message}"
        end
      end
    rescue => class_error
      puts "     Class checking failed: #{class_error.message}"
    end
    
    raise
  end
  
  puts "\n3. Testing Native SDK global operations..."
  begin
    # Test 1: Set a global value (from documentation example)
    puts "   Setting global ^TEST(\"KEY\") = \"Hello Native SDK\"..."
    iris_native.set("Hello Native SDK", "TEST", "KEY")
    puts "   ✅ Global set operation completed"
    
    # Test 2: Get the global value back
    puts "   Getting global ^TEST(\"KEY\")..."
    result = iris_native.getString("TEST", "KEY")
    puts "   ✅ Global get result: #{result.inspect}"
    
    # Test 3: Set and get patient data 
    puts "   Setting patient data ^DPT(9999,0)..."
    patient_data = "TEST,PATIENT^123456789^2850101^M"
    iris_native.set(patient_data, "DPT", 9999, 0)
    puts "   ✅ Patient data set"
    
    puts "   Getting patient data ^DPT(9999,0)..."
    retrieved_patient = iris_native.getString("DPT", 9999, 0)
    puts "   ✅ Patient data retrieved: #{retrieved_patient.inspect}"
    
  rescue => e
    puts "   ❌ Global operations failed: #{e.message}"
  end
  
  puts "\n4. Testing ObjectScript function calls..."
  begin
    # Test calling ObjectScript functions if available
    if iris_native.respond_to?(:functionString)
      puts "   Testing functionString with $HOROLOG..."
      horolog = iris_native.functionString("$HOROLOG")
      puts "   ✅ $HOROLOG result: #{horolog}"
    else
      puts "   ❌ functionString method not available"
    end
    
  rescue => e
    puts "   ❌ Function call failed: #{e.message}"
  end
  
  connection.close
  
rescue => e
  puts "❌ CRITICAL ERROR: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace:"
  e.backtrace.first(8).each { |line| puts "  #{line}" }
end