#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'

puts "🔧 Debug IRIS Connection"
puts "=" * 30

ENV['FILEBOT_DEBUG'] = '1'

begin
  puts "1. Creating IRIS adapter directly..."
  adapter = FileBot::Adapters::IRISAdapter.new({})
  puts "   ✅ Adapter created"
  
  puts "2. Checking @iris_native object..."
  iris_native = adapter.instance_variable_get(:@iris_native)
  puts "   @iris_native: #{iris_native.inspect}"
  puts "   @iris_native class: #{iris_native.class.name if iris_native}"
  
  puts "3. Testing connected? method..."
  connected = adapter.connected?
  puts "   connected?: #{connected}"
  
  if iris_native
    puts "4. Testing isConnected directly..."
    is_connected = iris_native.isConnected rescue "ERROR: #{$!.message}"
    puts "   isConnected: #{is_connected}"
  else
    puts "4. Skipping isConnected test (@iris_native is nil)"
  end
  
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts "Backtrace:"
  e.backtrace.first(5).each { |line| puts "  #{line}" }
end