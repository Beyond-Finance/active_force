require 'active_support/all'

module ActiveForce
  class CompositeBatchQuery
    def self.call(soql, sfdc_client = ActiveForce.sfdc_client)
      new(soql, sfdc_client).call
    end

    attr_reader :sfdc_client, :soql

    def initialize(soql, sfdc_client)
      @sfdc_client = sfdc_client
      @soql = soql
    end

    def call
      results = sfdc_client.batch do |subrequests|
        subrequests.requests << {
          method: "GET",
          url: "v#{subrequests.options[:api_version]}/query?" + {q: soql}.to_query
        }
      end

      r = results.first

      process_composite_batch_error_response(r) if r.statusCode >= 300

      r.result
    end

    private

    def process_composite_batch_error_response(r)
      response_value = {status: r.statusCode, body: r.result.as_json}
      error_code = r.result.dig(0, "errorCode")
      message = "#{error_code}: #{r.result.dig(0, "message")}"
      message << "\nRESPONSE: #{r.result.to_json}"

      raise Restforce::ErrorCode.get_exception_class(error_code).new(message, response_value)
    end
  end
end
