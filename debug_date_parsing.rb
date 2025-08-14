#!/usr/bin/env jruby

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
load 'lib/filebot.rb'

puts '🗓️ Testing date parsing...'
test_date = '2850101'
puts "Testing date: #{test_date}"
puts "Length: #{test_date.length}"

result = FileBot::DateFormatter.parse_fileman_date(test_date)
puts "Result: #{result.inspect}"

# The issue is that 2850101 (7 chars) should be FileMan format
# But 2850101 = year 285 + 1700 = 1985, month 01, day 01 
# Let's check if this is correct FileMan format

puts "\n📅 FileMan date analysis:"
puts "Year part (first 3): #{test_date[0..2]} + 1700 = #{test_date[0..2].to_i + 1700}"
puts "Month part: #{test_date[3..4]}"  
puts "Day part: #{test_date[5..6]}"

# Test with proper FileMan date
puts "\n🔄 Testing with different date formats..."
test_dates = [
  '2850101',  # Original
  '2850505',  # May 5th 
  '3231201'   # Future date
]

test_dates.each do |date|
  result = FileBot::DateFormatter.parse_fileman_date(date)
  puts "#{date} -> #{result}"
end