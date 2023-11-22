require 'csv'

module ActiveForce
  module Bulk
    class Records
      NULL_VALUE = '#N/A'.freeze

      attr_reader :headers, :data
      def initialize(headers:, data:)
        @headers = headers
        @data = data
      end

      def to_csv
        CSV.generate(String.new, headers: headers, write_headers: true) do |csv|
          data.each { |row| csv << row }
        end
      end

      def self.parse_from_attributes(records)
        # Sorting ensures that the headers line up with the values for the CSV
        headers = records.first.keys.sort.map(&:to_s)
        data = records.map do |r|
           r.transform_values { |v| transform_value_for_sf(v) }.sort.pluck(-1)
        end
        new(headers: headers, data: data)
      end

      # SF expects a special value for setting a column to be NULL.
      def self.transform_value_for_sf(value)
        case value
        when NilClass
          NULL_VALUE
        when Time
          value.iso8601
        else
          value.to_s
        end
      end
    end
  end
end