require 'active_force/bulk/job_result'

module ActiveForce
  module Bulk
    class Job
      attr_reader :operation, :records, :state, :options, :object, :content_url
      attr_accessor :id

      STATES = {
        Open: 'Open',
        UploadComplete: 'UploadComplete',
        InProgress: 'InProgress',
        JobComplete: 'JobComplete',
        Failed: 'Failed',
        Aborted: 'Aborted',
        Deleted: 'Deleted'
      }.freeze

      OPERATIONS = %i[insert delete hardDelete update upsert]

      def initialize(operation:, object:, id: nil, records: nil)
        @operation = operation.to_sym
        @object = object
        @id = id
        @records = records
        @state = nil
        @content_url = nil
        @options = options
        initialize_state_methods
      end

      def create
        request_body = default_job_options.merge(operation: operation, object: object)
        response = client.post("#{ingest_path}/", request_body)
        update_attributes_from(response)
        response
      end

      def upload
        headers = {"Content-Type": 'text/csv'}
        response = client.put(content_url, records.to_csv, headers)
        response
      end

      def result
        ActiveForce::Bulk::JobResult.new(job: self)
      end

      def self.run(...)
        job = new(...)
        job.create
        job.upload
        job.run
        job
      end

      def failed_results
        client.get("#{ingest_path}/#{id}/failedResults/")
      end

      def successful_results
        client.get("#{ingest_path}/#{id}/successfulResults/")
      end

      def info
        response = client.get("#{ingest_path}/#{id}")
        update_attributes_from(response)
        response
      end

      def run
        state(STATES[:UploadComplete])
      end

      def abort
        state(STATES[:Aborted])
      end

      def delete
        response = client.delete("#{ingest_path}/#{id}")
        response
      end

      def finished?
        job_complete? || failed? || aborted?
      end

      private
      attr_writer :state, :object, :operation, :content_url


      def ingest_path
        "/services/data/v#{client.options[:api_version]}/jobs/ingest"
      end

      def client
        @client ||= ActiveForce.sfdc_client
      end

      def default_job_options
        {
          columnDelimiter: 'COMMA',
          contentType: 'CSV',
          lineEnding: 'LF',
        }
      end

      def state(value)
        request_body = {state: value}
        headers = {"Content-Type": "application/json"}
        response = client.patch("#{ingest_path}/#{id}", request_body, headers)
        update_attributes_from(response)
        response
      end

      def update_attributes_from(response)
        return unless response.body.present?

        %i[id state object operation contentUrl].each do |attr|
          self.send("#{attr.to_s.underscore}=", response.body[attr.to_s]) if response.body[attr.to_s].present?
        end
      end

      # Defines question methods for various states of the job, e.g. #open?, #in_progress?, etc.
      def initialize_state_methods
        STATES.values.each do |state|
          state_method = <<-STATE_METHOD
            def #{state.to_s.underscore}?
              @state == '#{state}'
            end
          STATE_METHOD
          self.class_eval(state_method)
        end
      end
    end
  end
end