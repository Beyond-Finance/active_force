# frozen_string_literal: true

module ActiveForce
  module Composite
    ExceedsLimitsError = Class.new(Error)
    InvalidOperationError = Class.new(Error)

    class FailedRequestError < Error
      attr_reader :errors

      def initialize(responses)
        @errors = responses&.select(&:hasErrors)&.map(&:results)&.flatten || []
        super("Composite request had errors: #{errors}")
      end
    end
  end
end
