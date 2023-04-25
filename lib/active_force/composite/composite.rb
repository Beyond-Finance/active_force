# frozen_string_literal: true

module ActiveForce
  module Composite
    FailedRequestError = Class.new(ActiveForce::Error)
    ExceedsLimitsError = Class.new(ActiveForce::Error)
    InvalidOperationError = Class.new(ActiveForce::Error)
  end
end
