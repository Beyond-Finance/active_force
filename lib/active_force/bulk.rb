require 'active_force/bulk/job'
require 'active_force/bulk/records'

module ActiveForce
  module Bulk
    def bulk_insert_all(attributes)
      run_bulk_job(:insert, attributes)
    end

    def bulk_update_all(attributes)
      run_bulk_job(:update, attributes)
    end

    private

    def run_bulk_job(operation, attributes)
      records = Records.parse(translate_to_sf(attributes))
      job = Job.run(operation: operation, object: self.table_name, records: records)
      until job.finished? do
        job.info
        sleep(0.002) # short sleep so we can end our poll loop more quickly
      end
      job
    end

    def translate_to_sf(attributes)
      attributes.map{ |r| self.mapping.translate_to_sf(r) }
    end
  end
end