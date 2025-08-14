#!/usr/bin/env jruby

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
$LOAD_PATH.reject! { |path| path.include?('gems') && path.include?('filebot') }
load 'lib/filebot.rb'

ENV['FILEBOT_DEBUG'] = '1'

# Test direct global access for patient data
filebot = FileBot::Engine.new(:iris)

puts '🔍 Testing patient global access...'
# First set a patient record
filebot.adapter.set_global('^DPT', '9999', '0', 'TEST,PATIENT^123456789^2850101^M')
puts '   ✅ Patient data set in ^DPT(9999,0)'

# Then try to retrieve it
result = filebot.adapter.get_global('^DPT', '9999', '0')
puts "   ✅ Retrieved: #{result.inspect}"

# Test the patient method
puts '\n🏥 Testing patient demographics method...'
patient = filebot.get_patient_demographics('9999')
puts "   Patient method result: #{patient.inspect}"