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
  # so ids are sent in chunks of 200. Each chunk is all-or-none; chunks are
  # independent of each other.
  class CompositeCollectionDelete
    CHUNK_SIZE = 200
    # Salesforce reports an id that was deleted as ENTITY_IS_DELETED and one that
    # never existed as INVALID_CROSS_REFERENCE_KEY.
    MISSING = %w[ENTITY_IS_DELETED INVALID_CROSS_REFERENCE_KEY].freeze
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

    # Returns the number of records deleted. Ids that no longer exist count as 0.
    def call
      ids.each_slice(CHUNK_SIZE) { |chunk| @deleted_count += delete_chunk(chunk) }
      deleted_count
    end

    private

    def delete_chunk(chunk)
      failures = failures_for(chunk, request(chunk))
      return chunk.size if failures.empty?

      # Under allOrNone a missing id rolls back the rest of the chunk, so retry
      # without the ids that are already gone.
      raise DeleteFailed.new(real_errors(failures), deleted_count) unless failures.all? { |_, result| missing?(result) }

      remaining = chunk - failures.map(&:first)
      return 0 if remaining.empty?

      retry_failures = failures_for(remaining, request(remaining))
      raise DeleteFailed.new(real_errors(retry_failures), deleted_count) if retry_failures.any?

      remaining.size
    end

    def request(chunk)
      sfdc_client.api_delete('composite/sobjects', ids: chunk.join(','), allOrNone: true).body
    end

    # Pairs each failed result with its id, ignoring records that were only
    # rolled back because another record in the chunk failed.
    def failures_for(chunk, results)
      chunk.zip(results).reject { |_, result| result['success'] || rolled_back?(result) }
    end

    def real_errors(failures)
      failures.flat_map { |id, result| result['errors'].map { |error| error.to_h.merge('id' => id) } }
    end

    def rolled_back?(result)
      error_codes(result) == [ROLLED_BACK]
    end

    def missing?(result)
      codes = error_codes(result)
      codes.any? && codes.all? { |code| MISSING.include?(code) }
    end

    def error_codes(result)
      result['errors'].map { |error| error['statusCode'] }
    end
  end
end
