# frozen_string_literal: true

require 'active_force/errors'

module ActiveForce
  module Composite
    ExceedsLimitsError = Class.new(Error)
    #
    # Is raised when Salesforce returns a response with errors.
    #
    class FailedRequestError < Error
      attr_reader :errors

      def initialize(responses)
        @errors = responses&.select(&:hasErrors)&.map(&:results)&.flatten || []
        super("Composite request had errors: #{errors}")
      end
    end
  end
end
