require 'active_model/type/salesforce/multipicklist'
require 'active_model/type/salesforce/percent'
require 'active_force/version'
require 'active_force/sobject'
require 'active_force/query'
require 'active_force/bulk'

module ActiveForce

  class << self
    attr_accessor :sfdc_client
  end

  self.sfdc_client = Restforce.new

end
