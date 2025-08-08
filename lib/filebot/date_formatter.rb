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
      return nil if fileman_date.blank? || fileman_date.length != 7

      century = fileman_date[0].to_i < 5 ? "20" : "19"
      year = century + fileman_date[1..2]
      month = fileman_date[3..4]
      day = fileman_date[5..6]

      begin
        Date.parse("#{year}-#{month}-#{day}")
      rescue
        nil
      end
    end
  end
end
