require 'csv'

module ActiveForce
  module Bulk
    class Records
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

      def self.parse(records)
        headers = records.first.keys.sort
        data = records.map { |r| r.sort.pluck(-1) }
        new(headers: headers, data: data)
      end
    end
  end
end