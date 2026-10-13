require 'active_support/all'

module ActiveForce
  # Raised when Salesforce rejects one or more records of a delete. +errors+
  # holds the failing per-record results and +deleted_count+ the records that
  # were removed anyway, which stay deleted.
  class DeleteFailed < StandardError
    attr_reader :errors, :deleted_count

    def initialize(errors, deleted_count)
      @errors = errors
      @deleted_count = deleted_count

      super("Delete failed for #{errors.size} record(s) after deleting #{deleted_count}: #{errors.to_json}")
    end
  end

  # Deletes records through the Composite sObject Collections endpoint
  # (DELETE /composite/sobjects). Salesforce accepts at most 200 ids per request,
  # so ids are sent in chunks of 200. Requests are sent without allOrNone, so
  # every record succeeds or fails on its own and nothing is retried or rolled
  # back. Every chunk is attempted, and any real failures are raised together
  # once all chunks have run.
  class CompositeCollectionDelete
    CHUNK_SIZE = 200
    # Salesforce reports an id that was deleted as ENTITY_IS_DELETED and one that
    # never existed as INVALID_CROSS_REFERENCE_KEY.
    MISSING = %w[ENTITY_IS_DELETED INVALID_CROSS_REFERENCE_KEY].freeze

    def self.call(ids, sfdc_client = ActiveForce.sfdc_client)
      new(ids, sfdc_client).call
    end

    attr_reader :ids, :sfdc_client, :deleted_count, :errors

    def initialize(ids, sfdc_client)
      @ids = Array(ids).flatten.reject(&:blank?).uniq
      @sfdc_client = sfdc_client
      @deleted_count = 0
      @errors = []
    end

    # Returns the number of records deleted. Ids that no longer exist count as 0.
    # Raises DeleteFailed after all chunks ran if any record failed for another reason.
    def call
      ids.each_slice(CHUNK_SIZE) { |chunk| delete_chunk(chunk) }
      raise DeleteFailed.new(errors, deleted_count) if errors.any?

      deleted_count
    end

    private

    def delete_chunk(chunk)
      chunk.zip(request(chunk)).each do |id, result|
        if result['success']
          @deleted_count += 1
        elsif !missing?(result)
          errors.concat(result['errors'].map { |error| error.to_h.merge('id' => id) })
        end
      end
    end

    def request(chunk)
      sfdc_client.api_delete('composite/sobjects', ids: chunk.join(','), allOrNone: false).body
    end

    def missing?(result)
      codes = result['errors'].map { |error| error['statusCode'] }
      codes.any? && codes.all? { |code| MISSING.include?(code) }
    end
  end
end
