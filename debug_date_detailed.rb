#!/usr/bin/env jruby

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
load 'lib/filebot.rb'

puts '🔍 Detailed date parsing debug...'
test_date = '2850101'

puts "Input: #{test_date.inspect}"
puts "Length: #{test_date.length}"
puts "Empty check: #{test_date.nil? || test_date.to_s.strip.empty?}"

if test_date.length == 7
  fileman_year = test_date[0..2].to_i
  actual_year = fileman_year + 1700
  month = test_date[3..4]
  day = test_date[5..6]
  
  puts "FileMan year: #{fileman_year}"
  puts "Actual year: #{actual_year}"
  puts "Month: #{month}"
  puts "Day: #{day}"
  
  date_string = "#{actual_year}-#{month}-#{day}"
  puts "Date string: #{date_string}"
  
  begin
    require 'date'
    parsed_date = Date.parse(date_string)
    puts "✅ Parsed successfully: #{parsed_date}"
  rescue => e
    puts "❌ Parse failed: #{e.message}"
  end
else
  puts "❌ Wrong length: #{test_date.length}"
end

# Test the actual method
puts "\n🧪 Testing FileBot method..."
result = FileBot::DateFormatter.parse_fileman_date(test_date)
puts "Method result: #{result.inspect}"