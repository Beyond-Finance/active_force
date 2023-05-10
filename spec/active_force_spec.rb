# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ActiveForce do
  it 'should have a version number' do
    expect(ActiveForce::VERSION).to_not be_nil
  end

  describe '.sf_api_version' do
    it 'is nil if no sfdc_client' do
      described_class.sfdc_client = nil
      expect(described_class.sf_api_version).to be_nil
    end

    it 'is nil if sfdc_client does not specify a version' do
      described_class.sfdc_client = Restforce.new(api_version: nil)
      expect(described_class.sf_api_version).to be_nil
    end

    it 'is the version on the sfdc_client' do
      expected = '55.0'
      described_class.sfdc_client = Restforce.new(api_version: expected)
      expect(described_class.sf_api_version).to eq(expected)
    end
  end
end
