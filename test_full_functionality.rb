#!/usr/bin/env jruby

# Force load local version only
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }

load 'lib/filebot.rb'

puts "🔍 COMPREHENSIVE FileBot Functionality Test"
puts "=" * 50

begin
  puts "1. Creating FileBot Engine..."
  filebot = FileBot::Engine.new(:iris)
  puts "   ✅ Engine created: #{filebot.class.name}"
  
  puts "2. Testing IRIS connection..."
  connected = filebot.adapter.connected?
  puts "   Connection: #{connected ? '✅ Connected' : '❌ Not connected'}"
  
  puts "3. Testing MUMPS execution..."
  result = filebot.adapter.execute_mumps('W "Hello IRIS"')
  puts "   MUMPS result: #{result.inspect}"
  mumps_works = result && !result.strip.empty?
  puts "   MUMPS execution: #{mumps_works ? '✅ Working' : '❌ Returns empty'}"
  
  puts "4. Testing global operations..."
  puts "   Setting ^TEST(\"KEY\") = \"TestValue\"..."
  filebot.adapter.set_global('^TEST', 'KEY', 'TestValue')
  
  puts "   Getting ^TEST(\"KEY\")..."
  retrieved = filebot.adapter.get_global('^TEST', 'KEY')
  puts "   Retrieved: #{retrieved.inspect}"
  globals_work = retrieved == 'TestValue'
  puts "   Global operations: #{globals_work ? '✅ Working' : '❌ Not working'}"
  
  puts "5. Testing patient operations..."
  patient_data = {
    dfn: '9999',
    name: 'TEST,PATIENT',
    ssn: '999999999',
    dob: '1980-01-01',
    sex: 'M'
  }
  
  create_result = filebot.create_patient(patient_data)
  puts "   create_patient result: #{create_result.inspect}"
  create_works = create_result && create_result[:success]
  puts "   Patient creation: #{create_works ? '✅ Working' : '❌ Not working'}"
  
  if create_works
    puts "6. Testing patient retrieval..."
    patient = filebot.get_patient_demographics('9999')
    puts "   get_patient_demographics result: #{patient.inspect}"
    retrieval_works = patient && patient[:name] == 'TEST,PATIENT'
    puts "   Patient retrieval: #{retrieval_works ? '✅ Working' : '❌ Not working'}"
  else
    puts "6. Skipping patient retrieval (creation failed)"
  end
  
  puts "\n🎯 FUNCTIONALITY SUMMARY"
  puts "=" * 30
  puts "IRIS Connection:    #{connected ? '✅' : '❌'}"
  puts "MUMPS Execution:    #{mumps_works ? '✅' : '❌'}"
  puts "Global Operations:  #{globals_work ? '✅' : '❌'}"
  puts "Patient Creation:   #{create_works ? '✅' : '❌'}"
  if defined?(retrieval_works)
    puts "Patient Retrieval:  #{retrieval_works ? '✅' : '❌'}"
  end
  
  # Calculate overall functionality score
  total_tests = [connected, mumps_works, globals_work, create_works, defined?(retrieval_works) ? retrieval_works : false].count(true)
  total_possible = 5
  percentage = (total_tests.to_f / total_possible * 100).round
  
  puts "\n🏆 OVERALL STATUS: #{total_tests}/#{total_possible} tests passing (#{percentage}%)"
  
  if percentage == 100
    puts "🎉 FileBot is fully functional!"
  elsif percentage >= 60
    puts "⚠️  FileBot is partially functional"
  else
    puts "❌ FileBot needs significant fixes"
  end
  
rescue => e
  puts "❌ CRITICAL ERROR: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace:"
  e.backtrace.first(10).each { |line| puts "  #{line}" }
end