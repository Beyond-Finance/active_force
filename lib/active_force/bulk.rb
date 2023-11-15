require 'active_force/bulk/job'
require 'active_force/bulk/records'

module ActiveForce
  module Bulk
    class TimeoutError < Timeout::Error; end
    TIMEOUT_MESSAGE = 'Bulk job execution expired based on timeout of %{timeout} seconds'.freeze

    def bulk_insert_all(attributes, options={})
      run_bulk_job(:insert, attributes, options)
    end

    def bulk_update_all(attributes, options={})
      run_bulk_job(:update, attributes, options)
    end

    def bulk_delete_all(attributes, options={})
      run_bulk_job(:delete, attributes, options)
    end

    private

    def default_options
      {
        timeout: 30,
        sleep: 0.02 # short sleep so we can end our poll loop more quickly
      }
    end

    def run_bulk_job(operation, attributes, options)
      runtime_options = default_options.merge(options)
      records = Records.parse_from_attributes(translate_to_sf(attributes))
      job = Job.run(operation: operation, object: self.table_name, records: records)
      Timeout.timeout(runtime_options[:timeout], ActiveForce::Bulk::TimeoutError, TIMEOUT_MESSAGE % runtime_options) do
        until job.finished? do
          job.info
          sleep(runtime_options[:sleep])
        end
      end
      job.result
    end

    def translate_to_sf(attributes)
      attributes.map{ |r| self.mapping.translate_to_sf(r) }
    end
  end
end