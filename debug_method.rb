#!/usr/bin/env jruby

require_relative 'lib/filebot'

puts "🔧 Debug Method Signature"
puts "=" * 30

method = FileBot::DatabaseAdapterFactory.method(:create_adapter)
puts "Parameters: #{method.parameters.inspect}"
puts "Source location: #{method.source_location.inspect}"

puts "\nTrying call with no args..."
begin
  adapter = FileBot::DatabaseAdapterFactory.create_adapter()
  puts "✅ No args worked"
rescue => e
  puts "❌ No args failed: #{e.message}"
end

puts "\nTrying call with 1 arg..."
begin
  adapter = FileBot::DatabaseAdapterFactory.create_adapter(:iris)
  puts "✅ 1 arg worked"
rescue => e
  puts "❌ 1 arg failed: #{e.message}"
end

puts "\nTrying call with 2 args..."
begin
  adapter = FileBot::DatabaseAdapterFactory.create_adapter(:iris, {})
  puts "✅ 2 args worked"
rescue => e
  puts "❌ 2 args failed: #{e.message}"
end