require 'spec_helper'

describe ActiveForce::CompositeBatchQuery do
  let(:soql) { "SELECT Id FROM Account WHERE Name = 'Test'" }
  let(:api_version) { '58.0' }
  let(:sfdc_client) { double(Restforce) }
  let(:subrequests) do
    double('subrequests', requests: [], options: { api_version: api_version })
  end

  describe '.call' do
    it 'delegates to new(...).call' do
      result_record = double('result_record')
      instance = instance_double(described_class)
      allow(described_class).to receive(:new).with(soql, sfdc_client).and_return(instance)
      allow(instance).to receive(:call).and_return(result_record)

      expect(described_class.call(soql, sfdc_client)).to eq(result_record)
    end

    it 'defaults to ActiveForce.sfdc_client when no client is provided' do
      default_client = double(Restforce)
      allow(ActiveForce).to receive(:sfdc_client).and_return(default_client)

      instance = instance_double(described_class)
      allow(described_class).to receive(:new).with(soql, default_client).and_return(instance)
      allow(instance).to receive(:call).and_return(double('result'))

      expect { described_class.call(soql) }.not_to raise_error
      expect(described_class).to have_received(:new).with(soql, default_client)
    end
  end

  describe '#call' do
    context 'when the response is successful' do
      let(:result_record) { double(Restforce::Collection) }
      let(:batch_result) do
        double(Restforce::Mash, statusCode: 200, result: result_record)
      end

      before do
        allow(sfdc_client).to receive(:batch).and_yield(subrequests).and_return([batch_result])
      end

      it 'sends a GET batch subrequest with the correct URL' do
        described_class.call(soql, sfdc_client)

        expected_url = "v#{api_version}/query?" + { q: soql }.to_query
        expect(subrequests.requests).to include(
          hash_including(method: 'GET', url: expected_url)
        )
      end

      it 'returns the result from the batch response' do
        expect(described_class.call(soql, sfdc_client)).to eq(result_record)
      end
    end

    context 'when the response statusCode is exactly 300' do
      let(:error_body) do
        [{ 'errorCode' => 'MULTIPLE_CHOICES', 'message' => 'multiple records found' }]
      end
      let(:batch_result) do
        double('batch_result', statusCode: 300, result: error_body)
      end

      before do
        allow(sfdc_client).to receive(:batch).and_yield(subrequests).and_return([batch_result])
      end

      it 'treats it as an error' do
        expect {
          described_class.call(soql, sfdc_client)
        }.to raise_error(Restforce::ResponseError)
      end
    end

    context 'when the response is an error' do
      let(:error_body) do
        [{ 'errorCode' => 'MALFORMED_QUERY', 'message' => 'unexpected token' }]
      end
      let(:batch_result) do
        double(Restforce::Mash, statusCode: 400, result: error_body)
      end

      before do
        allow(sfdc_client).to receive(:batch).and_yield(subrequests).and_return([batch_result])
      end

      it 'raises a Restforce error with the correct error code and message' do
        expect {
          described_class.call(soql, sfdc_client)
        }.to raise_error(Restforce::ErrorCode::MalformedQuery) do |error|
          expect(error.message).to include('MALFORMED_QUERY')
          expect(error.message).to include('unexpected token')
          expect(error.message).to include('RESPONSE:')
        end
      end
    end
  end
end
