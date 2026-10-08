require 'spec_helper'

describe ActiveForce::CompositeCollectionDelete do
  let(:sfdc_client) { double('Client') }

  def success(id)
    { 'id' => id, 'success' => true, 'errors' => [] }
  end

  def failure(id, status_code, message = 'boom')
    { 'id' => id, 'success' => false, 'errors' => [{ 'statusCode' => status_code, 'message' => message, 'fields' => [] }] }
  end

  def rolled_back(id)
    failure(id, 'ALL_OR_NONE_OPERATION_ROLLED_BACK', 'Record rolled back because not all records were valid.')
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
    it 'deletes a single id via the composite sobjects endpoint with allOrNone' do
      expect(sfdc_client).to receive(:api_delete)
        .with('composite/sobjects', ids: '001', allOrNone: true)
        .and_return(response([success('001')]))

      expect(described_class.call(['001'], sfdc_client)).to eq 1
    end

    it 'sends multiple ids comma separated and returns the count deleted' do
      expect(sfdc_client).to receive(:api_delete)
        .with('composite/sobjects', ids: '001,002,003', allOrNone: true)
        .and_return(response(%w[001 002 003].map { |id| success(id) }))

      expect(described_class.call(%w[001 002 003], sfdc_client)).to eq 3
    end

    it 'ignores blank and duplicate ids' do
      expect(sfdc_client).to receive(:api_delete)
        .with('composite/sobjects', ids: '001,002', allOrNone: true)
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
      it 'counts it as 0 and still deletes the rest of the chunk' do
        calls = []
        allow(sfdc_client).to receive(:api_delete) do |_path, params|
          calls << params[:ids]
          if calls.size == 1
            response([success('001'), failure('002', 'ENTITY_IS_DELETED', 'entity is deleted'), rolled_back('003')])
          else
            response([success('001'), success('003')])
          end
        end

        expect(described_class.call(%w[001 002 003], sfdc_client)).to eq 2
        expect(calls).to eq ['001,002,003', '001,003']
      end

      it 'treats an id that never existed (INVALID_CROSS_REFERENCE_KEY) as missing too' do
        calls = []
        allow(sfdc_client).to receive(:api_delete) do |_path, params|
          calls << params[:ids]
          if calls.size == 1
            response([success('001'), failure('002', 'INVALID_CROSS_REFERENCE_KEY', 'invalid cross reference id'), rolled_back('003')])
          else
            response([success('001'), success('003')])
          end
        end

        expect(described_class.call(%w[001 002 003], sfdc_client)).to eq 2
        expect(calls).to eq ['001,002,003', '001,003']
      end

      it 'returns 0 without a retry when every id is gone' do
        expect(sfdc_client).to receive(:api_delete).once
          .and_return(response([failure('001', 'ENTITY_IS_DELETED')]))

        expect(described_class.call(['001'], sfdc_client)).to eq 0
      end
    end

    context 'when a chunk fails' do
      it 'raises DeleteFailed with the error details' do
        allow(sfdc_client).to receive(:api_delete)
          .and_return(response([failure('001', 'DELETE_FAILED', 'has child records'), rolled_back('002')]))

        expect { described_class.call(%w[001 002], sfdc_client) }
          .to raise_error(ActiveForce::DeleteFailed) { |error|
            expect(error.deleted_count).to eq 0
            expect(error.errors).to eq [{ 'id' => '001', 'statusCode' => 'DELETE_FAILED', 'message' => 'has child records', 'fields' => [] }]
            expect(error.message).to include('DELETE_FAILED', 'has child records')
          }
      end

      it 'reports records deleted by earlier chunks, which stay deleted' do
        ids = (1..250).map { |i| format('%018d', i) }
        calls = 0
        allow(sfdc_client).to receive(:api_delete) do |_path, params|
          calls += 1
          chunk = params[:ids].split(',')
          if calls == 1
            response(chunk.map { |id| success(id) })
          else
            response(chunk.map { |id| id == chunk.first ? failure(id, 'DELETE_FAILED') : rolled_back(id) })
          end
        end

        expect { described_class.call(ids, sfdc_client) }
          .to raise_error(ActiveForce::DeleteFailed) { |error| expect(error.deleted_count).to eq 200 }
      end

      it 'raises if the retry after removing missing ids also fails' do
        calls = 0
        allow(sfdc_client).to receive(:api_delete) do
          calls += 1
          if calls == 1
            response([failure('001', 'ENTITY_IS_DELETED'), rolled_back('002')])
          else
            response([failure('002', 'DELETE_FAILED')])
          end
        end

        expect { described_class.call(%w[001 002], sfdc_client) }.to raise_error(ActiveForce::DeleteFailed)
      end

      it 'raises when a missing id comes with a real failure' do
        allow(sfdc_client).to receive(:api_delete)
          .and_return(response([failure('001', 'ENTITY_IS_DELETED'), failure('002', 'DELETE_FAILED'), rolled_back('003')]))

        expect { described_class.call(%w[001 002 003], sfdc_client) }.to raise_error(ActiveForce::DeleteFailed)
      end
    end
  end
end
