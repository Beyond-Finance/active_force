require 'active_model/type/salesforce/multipicklist'
require 'active_model/type/salesforce/percent'
require 'active_force/version'
require 'active_force/sobject'
require 'active_force/query'

module ActiveForce
  class << self
    attr_accessor :sfdc_client

    def sf_api_version
      sfdc_client&.options&.fetch(:api_version, nil)
    end
  end

  self.sfdc_client = Restforce.new
end
