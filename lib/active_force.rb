require 'active_model/type/salesforce/multipicklist'
require 'active_model/type/salesforce/percent'
require 'active_force/version'
require 'active_force/sobject'
require 'active_force/query'
require 'active_force/bulk'

module ActiveForce

  class << self
    attr_accessor :sfdc_client
    attr_writer :composite_batch_query_size
  end

  self.sfdc_client = Restforce.new

  def self.composite_batch_query_size
    @composite_batch_query_size ||= 25_000

    return @composite_batch_query_size.call if @composite_batch_query_size.respond_to?(:call)

    @composite_batch_query_size
  end
end
