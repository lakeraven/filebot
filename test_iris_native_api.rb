#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'

puts "🔬 IRIS Native API Investigation"
puts "=" * 40

ENV['FILEBOT_DEBUG'] = '1'

begin
  require "java"
  
  # Load IRIS JARs
  FileBot::JarManager.load_iris_jars!
  
  # Import both JDBC and Native API classes
  java_import "com.intersystems.jdbc.IRISDriver"
  java_import "com.intersystems.binding.IRISDatabase"
  java_import "java.util.Properties"
  
  puts "1. Establishing JDBC connection..."
  driver = IRISDriver.new
  properties = Properties.new
  properties.setProperty("user", "_SYSTEM")
  properties.setProperty("password", "passwordpassword")
  
  connection_url = "jdbc:IRIS://localhost:1972/USER"
  jdbc_connection = driver.connect(connection_url, properties)
  puts "   ✅ JDBC connected: #{jdbc_connection.class.name}"
  
  puts "\n2. Attempting to get native database from JDBC..."
  begin
    native_db = IRISDatabase.getDatabase(jdbc_connection)
    puts "   ✅ Native database: #{native_db.class.name}"
    puts "   Native object: #{native_db.inspect}"
    
    # Check available methods on native database
    puts "\n   Available methods:"
    native_methods = native_db.java_class.declared_instance_methods.map(&:name).sort
    exec_methods = native_methods.select { |m| m.downcase.include?('exec') || m.downcase.include?('run') }
    exec_methods.each { |m| puts "     • #{m}" }
    
    puts "\n3. Testing native database operations..."
    
    # Test 1: runCommand (if available)
    if native_db.respond_to?(:runCommand)
      puts "   Testing runCommand..."
      result = native_db.runCommand('W "Hello from Native API"')
      puts "   ✅ runCommand result: #{result}"
    else
      puts "   ❌ runCommand not available"
    end
    
    # Test 2: execute (if available)
    if native_db.respond_to?(:execute)
      puts "   Testing execute..."
      result = native_db.execute('W "Hello from execute"')
      puts "   ✅ execute result: #{result}"
    else
      puts "   ❌ execute not available"
    end
    
  rescue => e
    puts "   ❌ Failed to get native database: #{e.message}"
  end
  
  puts "\n4. Alternative approach: Direct global access via SQL..."
  
  # Try using ObjectScript embedded SQL functions
  sql_tests = [
    "SELECT $SYSTEM.SQL.Functions.GetValue('^DPT', 1, 0)",
    "CALL $SYSTEM.SQL.Exec('SET ^TEST=\"Hello\", WRITE \"OK\"')", 
    "SELECT $EXTRACT($SYSTEM.SQL.Functions.GetValue('^TEST'))",
    "SELECT $GET(^DPT(1,0))"
  ]
  
  sql_tests.each_with_index do |sql, i|
    puts "   #{i+1}. #{sql}"
    begin
      stmt = jdbc_connection.createStatement
      if sql.start_with?('SELECT')
        result_set = stmt.executeQuery(sql)
        if result_set.next
          result = result_set.getString(1)
          puts "      ✅ Result: #{result}"
        else
          puts "      ✅ No result"
        end
        result_set.close
      else
        result = stmt.execute(sql)
        puts "      ✅ Executed: #{result}"
      end
      stmt.close
    rescue => e
      puts "      ❌ Failed: #{e.message.split("\n").first}"
    end
  end
  
  jdbc_connection.close
  
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts "Backtrace:"
  e.backtrace.first(3).each { |line| puts "  #{line}" }
end