require 'active_model/type/salesforce/multipicklist'
require 'active_model/type/salesforce/percent'
require 'active_force/version'
require 'active_force/sobject'
require 'active_force/query'
require 'active_force/bulk'

module ActiveForce

  class << self
    attr_accessor :sfdc_client
    attr_writer :composite_batch_query_threshold

    def composite_batch_query_threshold
      @composite_batch_query_threshold ||= 100_000

      return @composite_batch_query_threshold.call if @composite_batch_query_threshold.respond_to?(:call)

      @composite_batch_query_threshold
    end
  end

  self.sfdc_client = Restforce.new
end
