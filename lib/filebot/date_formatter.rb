# frozen_string_literal: true

module FileBot
  # Date formatting utilities for FileMan compatibility
  class DateFormatter
    def self.format_for_fileman(date)
      return "" unless date
      year = date.year - 1700
      sprintf("%03d%02d%02d", year, date.month, date.day)
    end

    def self.parse_fileman_date(fileman_date)
      return nil if fileman_date.nil? || fileman_date.to_s.strip.empty? || fileman_date.length != 7

      # FileMan date format: YYYMMDD where YYY is years since 1700
      fileman_year = fileman_date[0..2].to_i
      actual_year = fileman_year + 1700
      month = fileman_date[3..4]
      day = fileman_date[5..6]

      begin
        Date.parse("#{actual_year}-#{month}-#{day}")
      rescue
        nil
      end
    end
  end
end
