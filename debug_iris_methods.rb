#!/usr/bin/env jruby

# Force load local version
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'

puts "🔧 Debug IRIS Native API Methods"
puts "=" * 40

ENV['FILEBOT_DEBUG'] = '1'

begin
  adapter = FileBot::Adapters::IRISAdapter.new({})
  iris_native = adapter.instance_variable_get(:@iris_native)
  
  puts "IRIS Native object: #{iris_native.class.name}"
  puts "\nAvailable methods containing 'connect':"
  methods = iris_native.java_class.declared_instance_methods
  connect_methods = methods.select { |m| m.name.downcase.include?('connect') }
  connect_methods.each { |m| puts "  #{m.name}" }
  
  puts "\nAvailable methods containing 'get':"
  get_methods = methods.select { |m| m.name.downcase.include?('get') }
  get_methods.first(10).each { |m| puts "  #{m.name}" }
  
  puts "\nAvailable methods containing 'set':"
  set_methods = methods.select { |m| m.name.downcase.include?('set') }  
  set_methods.first(10).each { |m| puts "  #{m.name}" }
  
  puts "\nTesting basic method call..."
  # Try to call a simple method to verify the connection works
  begin
    result = iris_native.runCommand('W "Hello from IRIS"')
    puts "✅ runCommand worked: #{result}"
  rescue => e
    puts "❌ runCommand failed: #{e.message}"
  end
  
rescue => e
  puts "❌ ERROR: #{e.message}"
end