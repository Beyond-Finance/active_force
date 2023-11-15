require 'spec_helper'

describe ActiveForce::Bulk::Records do
  subject { described_class.new(headers: headers, data: data)}
  let(:headers) { %w[header1 header2] }
  let(:data) do
    [
      %w[value1 value2],
      %w[value3 value4],
    ]
  end
  describe '#to_csv' do
    it 'returns CSV with headers' do
      expect(subject.to_csv).to eq "header1,header2\nvalue1,value2\nvalue3,value4\n"
    end
  end
  describe '::parse_from_attributes' do
    subject { described_class.parse_from_attributes(attributes) }
    let(:attributes) do
      [
        { header1: 'value1', header2: 'value2'},
        { header1: 'value3', header2: 'value4'},
      ]
    end
    it 'parses array of hash attributes into Records object with headers and data' do
      records = subject
      expect(records).to be_a described_class
      expect(records.headers).to eq headers
      expect(records.data).to eq data
    end
  end
end
