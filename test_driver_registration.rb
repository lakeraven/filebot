#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'

puts "🔌 IRIS Driver Registration and Native SDK Test"
puts "=" * 50

ENV['FILEBOT_DEBUG'] = '1'

begin
  require "java"
  
  # Load IRIS JARs
  FileBot::JarManager.load_iris_jars!
  
  # Import the classes we need
  java_import "com.intersystems.jdbc.IRISDriver"
  java_import "com.intersystems.jdbc.IRISConnection" 
  java_import "java.sql.DriverManager"
  
  puts "1. Explicitly registering IRIS driver with DriverManager..."
  begin
    # Create and register the driver explicitly
    driver = IRISDriver.new
    DriverManager.registerDriver(driver)
    puts "   ✅ IRIS driver registered successfully"
    
    # Verify driver is registered
    drivers = DriverManager.getDrivers
    iris_driver_found = false
    while drivers.hasMoreElements
      driver_obj = drivers.nextElement
      if driver_obj.class.name.include?("IRIS")
        puts "   ✅ Found registered driver: #{driver_obj.class.name}"
        iris_driver_found = true
      end
    end
    
    unless iris_driver_found
      puts "   ⚠️ IRIS driver not found in registered drivers"
    end
    
  rescue => e
    puts "   ❌ Driver registration failed: #{e.message}"
    raise
  end
  
  puts "\n2. Creating connection using DriverManager..."
  begin
    conn_str = "jdbc:IRIS://localhost:1972/USER"
    user = "_SYSTEM"
    password = "passwordpassword"
    
    connection = DriverManager.getConnection(conn_str, user, password)
    puts "   ✅ DriverManager connection: #{connection.class.name}"
    
    # Cast to IRISConnection 
    iris_conn = connection.java_object
    puts "   ✅ Connection object: #{iris_conn.class.name}"
    
  rescue => e
    puts "   ❌ DriverManager connection failed: #{e.message}"
    
    # Fallback to direct driver approach
    puts "   🔄 Trying direct IRISDriver approach..."
    begin
      driver = IRISDriver.new
      properties = java.util.Properties.new
      properties.setProperty("user", user)  
      properties.setProperty("password", password)
      
      direct_conn = driver.connect(conn_str, properties)
      puts "   ✅ Direct driver connection: #{direct_conn.class.name}"
      connection = direct_conn
      iris_conn = direct_conn
      
    rescue => direct_error
      puts "   ❌ Direct driver connection failed: #{direct_error.message}"
      raise
    end
  end
  
  puts "\n3. Looking for IRIS Native SDK classes..."
  begin
    # Try to find and import the IRIS class for Native SDK
    possible_iris_classes = [
      "com.intersystems.jdbc.IRIS",
      "com.intersystems.binding.IRIS", 
      "com.intersystems.native.IRIS",
      "com.intersystems.iris.IRIS"
    ]
    
    iris_class = nil
    possible_iris_classes.each do |class_name|
      begin
        java_import class_name
        iris_class = eval(class_name.split('.').last)
        puts "   ✅ Found IRIS class: #{class_name}"
        break
      rescue => import_error
        puts "   ❌ #{class_name} not available: #{import_error.message}"
      end
    end
    
    if iris_class.nil?
      puts "   ⚠️ IRIS Native SDK class not found, checking available classes..."
      
      # Check what's actually available in the JARs
      puts "   Available classes in binding JAR:"
      # This would require more complex reflection to enumerate
      puts "   (Manual inspection of JAR contents needed)"
      
      raise "IRIS Native SDK class not found"
    end
    
  rescue => e
    puts "   ❌ IRIS class import failed: #{e.message}"
    raise
  end
  
  puts "\n4. Creating IRIS Native SDK object..."
  begin
    # Use the found IRIS class to create native SDK
    iris_native = iris_class.createIRIS(iris_conn)
    puts "   ✅ Native SDK created: #{iris_native.class.name}"
    
    # Test basic operations
    puts "\n5. Testing Native SDK operations..."
    
    # Test global set/get
    iris_native.set("Test Value", "FILEBOT", "TEST")
    result = iris_native.getString("FILEBOT", "TEST")
    puts "   ✅ Global test result: #{result}"
    
  rescue => e
    puts "   ❌ Native SDK creation failed: #{e.message}"
    puts "   Connection methods available:"
    iris_conn.java_class.declared_instance_methods.map(&:name).select { |m| 
      m.downcase.include?('create') || m.downcase.include?('iris') || m.downcase.include?('native')
    }.each { |m| puts "     • #{m}" }
  end
  
  connection.close if connection
  
rescue => e
  puts "❌ CRITICAL ERROR: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace:"
  e.backtrace.first(6).each { |line| puts "  #{line}" }
end