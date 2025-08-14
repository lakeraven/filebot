# frozen_string_literal: true

module FileBot
  # Parser utilities for patient data
  class PatientParser
    def self.parse_zero_node(dfn, data)
      return nil if data.nil? || data.to_s.strip.empty?

      fields = data.split("^")
      {
        dfn: dfn,
        name: fields[0],
        ssn: fields[1],
        dob: parse_fileman_date(fields[2]),
        sex: fields[3]
      }
    end

    def self.parse_clinical_summary(dfn, result)
      return nil if result.nil? || result.to_s.strip.empty?

      parts = result.split("~~")
      demo_data = parts[0]
      allergies_data = parts[1]
      vitals_data = parts[2]

      patient = parse_zero_node(dfn, demo_data)
      return nil unless patient

      # Add allergies
      patient[:allergies] = (allergies_data && !allergies_data.strip.empty?) ? allergies_data.split("~") : []

      # Add vitals
      if vitals_data && !vitals_data.strip.empty?
        vital_parts = vitals_data.split("^")
        patient[:latest_visit] = {
          date: parse_fileman_date(vital_parts[0]),
          location: vital_parts[2]
        }
      end

      patient
    end

    private

    def self.parse_fileman_date(fileman_date)
      return nil if fileman_date.nil? || fileman_date.to_s.strip.empty? || fileman_date.length != 7

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
