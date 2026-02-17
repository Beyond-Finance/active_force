require 'spec_helper'

describe ActiveForce do
  it 'should have a version number' do
    expect(ActiveForce::VERSION).to_not be_nil
  end

  describe '.composite_batch_query_threshold' do
    after do
      ActiveForce.instance_variable_set(:@composite_batch_query_threshold, nil)
    end

    it 'returns 100_000 by default' do
      expect(ActiveForce.composite_batch_query_threshold).to eq(100_000)
    end

    it 'allows setting a custom integer value' do
      ActiveForce.composite_batch_query_threshold = 25_000
      expect(ActiveForce.composite_batch_query_threshold).to eq(25_000)
    end

    it 'supports callable values (proc/lambda)' do
      ActiveForce.composite_batch_query_threshold = -> { 50_000 }
      expect(ActiveForce.composite_batch_query_threshold).to eq(50_000)
    end
  end
end
