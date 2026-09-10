require 'spec_helper'

describe 'query.active_force notifications' do
  let(:model) do
    Class.new(ActiveForce::SObject) do
      self.table_name = 'Widgets'
      field :id, from: 'Id'
      field :amount, from: 'Amount__c'
    end
  end
  let(:client) { double('client') }
  let(:query) { ActiveForce::ActiveQuery.new(model) }
  let(:events) { [] }

  around do |example|
    subscriber = ActiveSupport::Notifications.subscribe('query.active_force') do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end
    example.run
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  before do
    allow(model).to receive(:sfdc_client).and_return(client)
  end

  it 'emits the SOQL, model, nonsecret client identity and direct transport without enumerating the result' do
    result = double('unloaded collection')
    expect(client).to receive(:query).with(query.to_s).and_return(result)
    expect(query.send(:result)).to equal(result)
    expect(events.size).to eq(1)
    expect(events.first.payload).to eq(soql: query.to_s, model: model,
      client_id: client.object_id, transport: :query)
  end

  it 'does not emit for lazy construction or SOQL rendering' do
    query.where(id: 'fake-id').select(:id).to_s
    expect(events).to be_empty
  end

  it 'does not emit again when loaded records are reused' do
    expect(client).to receive(:query).once.and_return([])
    result = query.to_a
    expect(query.to_a).to equal(result)
    expect(events.size).to eq(1)
  end

  it 'counts separate logical queries even when a client returns the same cached result' do
    cached_result = []
    expect(client).to receive(:query).twice.and_return(cached_result)
    2.times { ActiveForce::ActiveQuery.new(model).to_a }
    expect(events.size).to eq(2)
    expect(events.map(&:payload).uniq.size).to eq(1)
    expect(events.first.payload).not_to have_key(:cache_hit)
  end

  it 'does not emit for pages retrieved while enumerating the returned collection' do
    collection = double('paginated collection')
    expect(client).to receive(:query).once.and_return(collection)
    expect(collection).to receive(:to_a) do
      client.get('/fake/next-page')
      []
    end
    expect(client).to receive(:get).with('/fake/next-page')
    query.to_a
    expect(events.size).to eq(1)
  end

  it 'emits once when the client retries internally' do
    attempts = 0
    allow(client).to receive(:query) do
      begin
        attempts += 1
        raise IOError if attempts == 1
        []
      rescue IOError
        retry
      end
    end
    query.to_a
    expect(attempts).to eq(2)
    expect(events.size).to eq(1)
  end

  it 'distinguishes client instances' do
    other_client = double('other client', query: [])
    allow(client).to receive(:query).and_return([])
    query.to_a
    allow(model).to receive(:sfdc_client).and_return(other_client)
    ActiveForce::ActiveQuery.new(model).to_a
    expect(events.map { |event| event.payload[:client_id] }).to eq([client.object_id, other_client.object_id])
  end

  [:query, :composite_batch].each do |transport|
    context "with #{transport} transport" do
      before do
        allow(ActiveForce).to receive(:composite_batch_query_threshold).and_return(transport == :query ? 100_000 : 0)
      end

      it 'preserves the result and emits one event' do
        result = double('unloaded result')
        if transport == :query
          expect(client).to receive(:query).with(query.to_s).and_return(result)
        else
          expect(client).not_to receive(:query)
          expect(ActiveForce::CompositeBatchQuery).to receive(:call).with(query.to_s, client).and_return(result)
        end
        expect(query.send(:result)).to equal(result)
        expect(events.size).to eq(1)
        expect(events.first.payload[:transport]).to eq(transport)
      end

      it 'preserves the original exception and standard notification error payload' do
        error = IOError.new('fake failure')
        if transport == :query
          allow(client).to receive(:query).and_raise(error)
        else
          allow(ActiveForce::CompositeBatchQuery).to receive(:call).and_raise(error)
        end
        expect { query.to_a }.to raise_error { |raised| expect(raised).to equal(error) }
        expect(events.size).to eq(1)
        expect(events.first.payload).to include(exception: ['IOError', 'fake failure'], exception_object: error,
          transport: transport, soql: query.to_s, model: model, client_id: client.object_id)
        expect(query.loaded?).to be false
      end
    end
  end

  [:count, :sum].each do |operation|
    context "##{operation}" do
      let(:arguments) { operation == :sum ? [:amount] : [] }

      before do
        allow(ActiveForce).to receive(:composite_batch_query_threshold).and_return(0)
      end

      it 'retains direct query transport and the aggregate value even above the composite threshold' do
        expect(ActiveForce::CompositeBatchQuery).not_to receive(:call)
        aggregate = double('aggregate', expr0: 42)
        expect(client).to receive(:query).and_return([aggregate])
        expect(query.public_send(operation, *arguments)).to eq(42)
        expect(events.size).to eq(1)
        expression = operation == :sum ? 'sum(Amount__c)' : 'count(Id)'
        expect(events.first.payload).to eq(soql: "SELECT #{expression} FROM Widgets", model: model,
          client_id: client.object_id, transport: :query)
      end

      it 'reports failed aggregate executions without replacing the exception' do
        error = IOError.new('fake aggregate failure')
        allow(client).to receive(:query).and_raise(error)
        expect { query.public_send(operation, *arguments) }.to raise_error { |raised| expect(raised).to equal(error) }
        expect(events.size).to eq(1)
        expect(events.first.payload[:exception_object]).to equal(error)
      end
    end
  end

  it 'does not emit for invalid sum arguments' do
    expect { query.sum(nil) }.to raise_error(ArgumentError)
    expect { query.sum(:unknown) }.to raise_error(ActiveForce::UnknownFieldError)
    expect(events).to be_empty
  end
end
