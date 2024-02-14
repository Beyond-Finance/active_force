module ActiveForce
  module Bulk
    class JobResult
      attr_reader :job, :failed, :successful, :stats, :errors

      def initialize(job:)
        @job = job
        @stats = result_from_job_info
        @failed = failed_results
        @successful = successful_results
        @errors = errors_from_failed_results
      end

      def success?
        failed.blank? && successful.present?
      end

      private
      attr_writer :errors, :failed, :successful

      def errors_from_failed_results
        return [] if @stats[:number_records_failed].zero? || self.failed.blank?

        self.errors = self.failed.pluck('sf__Error').uniq
      end

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