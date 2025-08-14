#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'

puts "🧪 Simple Global Test"
puts "=" * 30

ENV['FILEBOT_DEBUG'] = '1'

begin
  adapter = FileBot::Adapters::IRISAdapter.new({})
  
  puts "1. Testing direct SQL approaches..."
  
  # Test different SQL patterns to find what works
  sql_tests = [
    "SELECT 'Hello World'",
    "SELECT $HOROLOG",
    "SELECT $JOB",
    "DO $ZW",  
    "SET ^TEST=\"Hello\"",
    "WRITE \"Test\""
  ]
  
  sql_tests.each_with_index do |sql, i|
    puts "   #{i+1}. Testing: #{sql}"
    begin
      stmt = adapter.instance_variable_get(:@iris_native).createStatement
      if sql.start_with?('SELECT')
        result_set = stmt.executeQuery(sql)
        if result_set.next
          result = result_set.getString(1)
          puts "      ✅ Result: #{result}"
        end
        result_set.close
      else
        result = stmt.execute(sql)
        puts "      ✅ Executed: #{result}"
      end
      stmt.close
    rescue => e
      puts "      ❌ Failed: #{e.message}"
    end
  end
  
  puts "\n2. Testing ObjectScript execution..."
  
  # Test if we can execute ObjectScript directly
  objectscript_tests = [
    "write \"Hello from ObjectScript\"",
    "set ^GLOBAL=\"test\", write \"OK\"",
    "write $get(^GLOBAL)"
  ]
  
  objectscript_tests.each_with_index do |code, i|
    puts "   #{i+1}. Testing: #{code}"
    begin
      # Try the irisExec method if available
      iris_conn = adapter.instance_variable_get(:@iris_native)
      if iris_conn.respond_to?(:irisExec)
        result = iris_conn.irisExec(code)
        puts "      ✅ irisExec result: #{result}"
      else
        puts "      ❌ irisExec method not available"
      end
    rescue => e
      puts "      ❌ Failed: #{e.message}"
    end
  end
  
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts "Backtrace:"
  e.backtrace.first(5).each { |line| puts "  #{line}" }
end