#!/usr/bin/env jruby

puts "🔧 Debug FileBot Instantiation"
puts "=" * 40

begin
  puts "1. Loading FileBot module..."
  require_relative 'lib/filebot'
  puts "   ✅ FileBot module loaded"
  
  puts "2. Testing DatabaseAdapterFactory..."
  adapter = FileBot::DatabaseAdapterFactory.create_adapter(:iris, {})
  puts "   ✅ IRIS adapter created: #{adapter.class.name}"
  
  puts "3. Testing Core class directly..."
  core = FileBot::Core.new(adapter, {})
  puts "   ✅ Core created: #{core.class.name}"
  
  puts "4. Testing Engine class..."
  engine = FileBot::Engine.new(:iris, {})
  puts "   ✅ Engine created: #{engine.class.name}"
  
  puts "5. Testing convenience method..."
  filebot = FileBot.new(:iris)
  puts "   ✅ FileBot.new worked: #{filebot.class.name}"
  
rescue => e
  puts "❌ ERROR at step: #{e.message}"
  puts "   Backtrace:"
  e.backtrace.first(3).each { |line| puts "     #{line}" }
end