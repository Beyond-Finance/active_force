require 'active_force/bulk/job'
require 'active_force/bulk/records'

module ActiveForce
  module Bulk
    def bulk_insert_all(attributes)
      run_bulk_job(:insert, attributes)
    end

    private

    def run_bulk_job(operation, attributes)
      records = Records.parse(translate_to_sf(attributes))
      job = Job.new(operation: operation, object: self.table_name, records: records)
      job.run!
      until job.finished? do
        job.info

        sleep(0.002)
      end
      job
    end

    def translate_to_sf(attributes)
      attributes.map{ |r| self.mapping.translate_to_sf(r) }
    end
  end
end