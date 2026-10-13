require 'spec_helper'

describe ActiveForce::CompositeCollectionDelete do
  let(:sfdc_client) { double('Client') }

  def success(id)
    { 'id' => id, 'success' => true, 'errors' => [] }
  end

  def failure(id, status_code, message = 'boom')
    { 'id' => id, 'success' => false, 'errors' => [{ 'statusCode' => status_code, 'message' => message, 'fields' => [] }] }
  end

  def response(results)
    double('Response', body: results)
  end

  describe '.call' do
    it 'defaults to ActiveForce.sfdc_client' do
      allow(ActiveForce).to receive(:sfdc_client).and_return(sfdc_client)
      allow(sfdc_client).to receive(:api_delete).and_return(response([success('001')]))

      described_class.call(['001'])

      expect(sfdc_client).to have_received(:api_delete)
    end
  end

  describe '#call' do
    it 'deletes a single id via the composite sobjects endpoint without allOrNone' do
      expect(sfdc_client).to receive(:api_delete)
        .with('composite/sobjects', ids: '001', allOrNone: false)
        .and_return(response([success('001')]))

      expect(described_class.call(['001'], sfdc_client)).to eq 1
    end

    it 'sends multiple ids comma separated and returns the count deleted' do
      expect(sfdc_client).to receive(:api_delete)
        .with('composite/sobjects', ids: '001,002,003', allOrNone: false)
        .and_return(response(%w[001 002 003].map { |id| success(id) }))

      expect(described_class.call(%w[001 002 003], sfdc_client)).to eq 3
    end

    it 'ignores blank and duplicate ids' do
      expect(sfdc_client).to receive(:api_delete)
        .with('composite/sobjects', ids: '001,002', allOrNone: false)
        .and_return(response([success('001'), success('002')]))

      expect(described_class.call(['001', nil, '', '001', '002'], sfdc_client)).to eq 2
    end

    it 'makes no request and returns 0 when there are no ids' do
      expect(sfdc_client).not_to receive(:api_delete)

      expect(described_class.call([nil], sfdc_client)).to eq 0
      expect(described_class.call([], sfdc_client)).to eq 0
    end

    context 'with more ids than fit in one request' do
      let(:ids) { (1..450).map { |i| format('%018d', i) } }

      it 'chunks into requests of 200 ids' do
        sent = []
        allow(sfdc_client).to receive(:api_delete) do |_path, params|
          chunk = params[:ids].split(',')
          sent << chunk
          response(chunk.map { |id| success(id) })
        end

        expect(described_class.call(ids, sfdc_client)).to eq 450
        expect(sent.map(&:size)).to eq [200, 200, 50]
        expect(sent.flatten).to eq ids
      end
    end

    context 'when an id no longer exists' do
      it 'counts it as 0 in a single request and still deletes the rest' do
        expect(sfdc_client).to receive(:api_delete).once
          .and_return(response([success('001'), failure('002', 'ENTITY_IS_DELETED', 'entity is deleted'), success('003')]))

        expect(described_class.call(%w[001 002 003], sfdc_client)).to eq 2
      end

      it 'treats an id that never existed (INVALID_CROSS_REFERENCE_KEY) as missing too' do
        expect(sfdc_client).to receive(:api_delete).once
          .and_return(response([success('001'), failure('002', 'INVALID_CROSS_REFERENCE_KEY'), success('003')]))

        expect(described_class.call(%w[001 002 003], sfdc_client)).to eq 2
      end

      it 'returns 0 when every id is gone' do
        expect(sfdc_client).to receive(:api_delete).once
          .and_return(response([failure('001', 'ENTITY_IS_DELETED')]))

        expect(described_class.call(['001'], sfdc_client)).to eq 0
      end
    end

    context 'when a record fails for another reason' do
      it 'raises DeleteFailed with the error details, keeping the other deletes' do
        allow(sfdc_client).to receive(:api_delete)
          .and_return(response([failure('001', 'DELETE_FAILED', 'has child records'), success('002')]))

        expect { described_class.call(%w[001 002], sfdc_client) }
          .to raise_error(ActiveForce::DeleteFailed) { |error|
            expect(error.deleted_count).to eq 1
            expect(error.errors).to eq [{ 'id' => '001', 'statusCode' => 'DELETE_FAILED', 'message' => 'has child records', 'fields' => [] }]
            expect(error.message).to include('DELETE_FAILED', 'has child records')
          }
      end

      it 'does not report a missing id as an error' do
        allow(sfdc_client).to receive(:api_delete)
          .and_return(response([failure('001', 'ENTITY_IS_DELETED'), failure('002', 'DELETE_FAILED'), success('003')]))

        expect { described_class.call(%w[001 002 003], sfdc_client) }
          .to raise_error(ActiveForce::DeleteFailed) { |error|
            expect(error.errors.map { |e| e['id'] }).to eq %w[002]
            expect(error.deleted_count).to eq 1
          }
      end

      it 'attempts every chunk and collects errors across them' do
        ids = (1..450).map { |i| format('%018d', i) }
        sent = []
        allow(sfdc_client).to receive(:api_delete) do |_path, params|
          chunk = params[:ids].split(',')
          sent << chunk
          response(chunk.map { |id| id == chunk.first ? failure(id, 'DELETE_FAILED') : success(id) })
        end

        expect { described_class.call(ids, sfdc_client) }
          .to raise_error(ActiveForce::DeleteFailed) { |error|
            expect(sent.size).to eq 3
            expect(error.deleted_count).to eq 447
            expect(error.errors.map { |e| e['id'] }).to eq sent.map(&:first)
          }
      end
    end
  end
end
