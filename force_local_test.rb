#!/usr/bin/env jruby

# Force load local version only
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

puts "🔧 Force Local FileBot Test"
puts "=" * 30

begin
  puts "Loading local FileBot..."
  load 'lib/filebot.rb'
  puts "✅ Local version loaded"
  
  puts "Testing DatabaseAdapterFactory method..."
  method = FileBot::DatabaseAdapterFactory.method(:create_adapter)
  puts "Parameters: #{method.parameters.inspect}"
  puts "Source: #{method.source_location.inspect}"
  
  puts "Testing with :iris..."
  adapter = FileBot::DatabaseAdapterFactory.create_adapter(:iris)
  puts "✅ Adapter created: #{adapter.class.name}"
  
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts "Backtrace:"
  e.backtrace.first(5).each { |line| puts "  #{line}" }
end