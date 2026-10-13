require 'active_support/all'

module ActiveForce
  # Raised when Salesforce rejects a delete. +errors+ holds the failing
  # per-record results and +deleted_count+ the records removed by earlier
  # chunks of the same call, which stay deleted.
  class DeleteFailed < StandardError
    attr_reader :errors, :deleted_count

    def initialize(errors, deleted_count)
      @errors = errors
      @deleted_count = deleted_count

      super("Delete failed after deleting #{deleted_count} record(s): #{errors.to_json}")
    end
  end

  # Deletes records through the Composite sObject Collections endpoint
  # (DELETE /composite/sobjects). Salesforce accepts at most 200 ids per request,
  # so ids are sent in chunks of 200. Each chunk is all-or-none and chunks are
  # independent of each other. The first chunk with a failing record raises
  # DeleteFailed and the remaining chunks are not sent; nothing is retried or
  # worked around, including ids that are already deleted or never existed.
  class CompositeCollectionDelete
    CHUNK_SIZE = 200
    ROLLED_BACK = 'ALL_OR_NONE_OPERATION_ROLLED_BACK'.freeze

    def self.call(ids, sfdc_client = ActiveForce.sfdc_client)
      new(ids, sfdc_client).call
    end

    attr_reader :ids, :sfdc_client, :deleted_count

    def initialize(ids, sfdc_client)
      @ids = Array(ids).flatten.reject(&:blank?).uniq
      @sfdc_client = sfdc_client
      @deleted_count = 0
    end

    # Returns the number of records deleted.
    def call
      ids.each_slice(CHUNK_SIZE) { |chunk| delete_chunk(chunk) }
      deleted_count
    end

    private

    def delete_chunk(chunk)
      failures = chunk.zip(request(chunk)).reject { |_, result| result['success'] }
      raise DeleteFailed.new(errors_for(failures), deleted_count) if failures.any?

      @deleted_count += chunk.size
    end

    def request(chunk)
      sfdc_client.api_delete('composite/sobjects', ids: chunk.join(','), allOrNone: true).body
    end

    # Reports the records that failed for a reason of their own. Records only
    # rolled back because another one failed are left out, unless nothing else
    # explains the failure.
    def errors_for(failures)
      causes = failures.reject { |_, result| rolled_back?(result) }
      (causes.presence || failures).flat_map do |id, result|
        result['errors'].map { |error| error.to_h.merge('id' => id) }
      end
    end

    def rolled_back?(result)
      result['errors'].map { |error| error['statusCode'] } == [ROLLED_BACK]
    end
  end
end
