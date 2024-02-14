require 'spec_helper'

# Set up a new SObject to test the mixin.
class FooBarSObject < ActiveForce::SObject
  field :id, from: 'Id'
  field :baz_id, from: 'Baz_id__c'
end

describe ActiveForce::Bulk do
  subject { FooBarSObject }
  let(:attributes) do
    [
      {id: 1, baz_id: 1 },
      {id: 2, baz_id: 1 },
      {id: 3, baz_id: 2 },
    ]
  end
  let(:job) { double(ActiveForce::Bulk::Job) }
  let(:timeout_message) { /Bulk job execution expired based on timeout of/ }
  before do
    allow(job).to receive(:result)
  end

  describe '::bulk_insert_all' do
    before do
      allow(ActiveForce::Bulk::Job).to receive(:run).with(hash_including(operation: :insert)).and_return(job)
    end

    it 'runs a bulk insert job' do
      allow(job).to receive(:finished?).and_return(true)
      subject.bulk_insert_all(attributes)
    end

    context 'when job takes a while to run' do
      it 'polls job info until job is finished' do
        allow(job).to receive(:finished?).and_return(false, false, true)
        allow(job).to receive(:info)
        subject.bulk_insert_all(attributes)
      end
    end

    context 'when job run exceeds timeout' do
      it 'raises error' do
        allow(job).to receive(:finished?).and_return(false)
        allow(job).to receive(:info)
        expect do
          subject.bulk_insert_all(attributes, timeout: 0.1)
        end.to raise_error(ActiveForce::Bulk::TimeoutError, timeout_message)
      end
    end
  end

  describe '::bulk_update_all' do
    before do
      allow(ActiveForce::Bulk::Job).to receive(:run).with(hash_including(operation: :update)).and_return(job)
    end

    it 'runs a bulk insert job' do
      allow(job).to receive(:finished?).and_return(true)
      subject.bulk_update_all(attributes)
    end

    context 'when job takes a while to run' do
      it 'polls job info until job is finished' do
        allow(job).to receive(:finished?).and_return(false, false, true)
        allow(job).to receive(:info)
        subject.bulk_update_all(attributes)
      end
    end

    context 'when job run exceeds timeout' do
      it 'raises error' do
        allow(job).to receive(:finished?).and_return(false)
        allow(job).to receive(:info)
        expect do
          subject.bulk_update_all(attributes, timeout: 0.1)
        end.to raise_error(ActiveForce::Bulk::TimeoutError, timeout_message)
      end
    end
  end

  describe '::bulk_delete_all' do
    before do
      allow(ActiveForce::Bulk::Job).to receive(:run).with(hash_including(operation: :delete)).and_return(job)
    end

    it 'runs a bulk insert job' do
      allow(job).to receive(:finished?).and_return(true)
      subject.bulk_delete_all(attributes)
    end

    context 'when job takes a while to run' do
      it 'polls job info until job is finished' do
        allow(job).to receive(:finished?).and_return(false, false, true)
        allow(job).to receive(:info)
        subject.bulk_delete_all(attributes)
      end
    end

    context 'when job run exceeds timeout' do
      it 'raises error' do
        allow(job).to receive(:finished?).and_return(false)
        allow(job).to receive(:info)
        expect do
          subject.bulk_delete_all(attributes, timeout: 0.1)
        end.to raise_error(ActiveForce::Bulk::TimeoutError, timeout_message)
      end
    end
  end
end
