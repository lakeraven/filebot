#!/usr/bin/env jruby

require_relative 'lib/filebot'

puts "🔍 HONEST FileBot Reality Check"
puts "=" * 40

begin
  puts "1. Creating FileBot instance..."
  filebot = FileBot.new(:iris)
  puts "   ✅ FileBot created"
  
  puts "2. Testing IRIS connection..."
  connected = filebot.adapter.connected?
  puts "   Connection status: #{connected ? '✅ Connected' : '❌ Not connected'}"
  
  puts "3. Testing MUMPS execution..."
  result = filebot.adapter.execute_mumps('W "Hello IRIS"')
  puts "   execute_mumps result: #{result.inspect}"
  puts "   Does it actually work? #{result && !result.empty? ? '✅ YES' : '❌ NO - returns empty/nil'}"
  
  puts "4. Testing global operations..."
  puts "   Setting ^TEST(\"KEY\") = \"VALUE\"..."
  filebot.adapter.set_global('^TEST', 'KEY', 'VALUE')
  
  puts "   Getting ^TEST(\"KEY\")..."
  retrieved = filebot.adapter.get_global('^TEST', 'KEY')
  puts "   Retrieved value: #{retrieved.inspect}"
  puts "   Does set/get work? #{retrieved == 'VALUE' ? '✅ YES' : '❌ NO'}"
  
  puts "5. Testing patient creation..."
  patient_result = filebot.create_patient({
    dfn: '1234',
    name: 'TEST,PATIENT',
    ssn: '123456789',
    dob: '1980-01-01',
    sex: 'M'
  })
  puts "   create_patient result: #{patient_result.inspect}"
  puts "   Does patient creation work? #{patient_result && patient_result[:success] ? '✅ YES' : '❌ NO'}"
  
  if patient_result && patient_result[:success]
    puts "6. Testing patient retrieval..."
    patient = filebot.get_patient_demographics('1234')
    puts "   get_patient_demographics result: #{patient.inspect}"
    puts "   Does patient retrieval work? #{patient && patient[:name] == 'TEST,PATIENT' ? '✅ YES' : '❌ NO'}"
  end
  
rescue => e
  puts "❌ CRITICAL ERROR: #{e.message}"
  puts "   Error class: #{e.class}"
end

puts "\n🎯 REALITY CHECK SUMMARY"
puts "=" * 40
puts "The above test shows exactly what works and what doesn't."
puts "No excuses, no false claims, just the truth."