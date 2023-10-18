module ActiveForce
  module Bulk
    class JobResult
      attr_reader :job, :failed, :successful, :stats

      def initialize(job:)
        @job = job
        @stats = result_from_job_info
        @failed = failed_results
        @successful = successful_results
      end

      def success?
        failed.blank? && successful.present?
      end

      private
      attr_writer :failed, :successful

      def failed_results
        return [] if @stats[:number_records_failed].zero?

        response = job.failed_results
        self.failed = CSV.parse(response.body, headers: true).map(&:to_h)
      end

      def successful_results
        response = job.successful_results
        self.successful = CSV.parse(response.body, headers: true).map(&:to_h)
      end

      def job_info
        job.info
      end

      def result_from_job_info
        job_info&.body.slice('numberRecordsProcessed', 'numberRecordsFailed', 'totalProcessingTime').transform_keys { |k| k.to_s.underscore.to_sym }
      end
    end
  end
end