require 'spec_helper'

describe ActiveForce::Bulk::Job do
  subject { described_class.new(**args)}
  let(:args) { { operation: operation, object: object, id: id, records: records } }
  let(:operation) { described_class::OPERATIONS.sample }
  let(:object) { 'Whizbang__c' }
  let(:id) { nil }
  let(:records) { instance_double(ActiveForce::Bulk::Records) }
  let(:sfdc_client) { spy(ActiveForce.sfdc_client.class)}
  let(:state) { 'Open' }
  let(:api_version) { '58.0' }
  let(:ingest_url) { "/services/data/v#{api_version}/jobs/ingest" }

  before do
    allow(ActiveForce).to receive(:sfdc_client).and_return(sfdc_client)
    allow(sfdc_client).to receive(:options).and_return({api_version: api_version})
    allow(records).to receive(:to_csv)
  end

  describe '#finished?' do
    let(:finished_state) { described_class::STATES.slice(:JobComplete, :Failed, :Aborted).values.sample }
    let(:unfinished_state) { described_class::STATES.except(:JobComplete, :Failed, :Aborted).values.sample }

    context 'when job is in one of the finished states' do
      it 'returns true' do
        job = subject
        job.instance_variable_set(:@state, finished_state)
        expect(job.finished?).to be true
      end
    end

    context 'when job is NOT in one of the finished states' do
      it 'returns false' do
        job = subject
        job.instance_variable_set(:@state, unfinished_state)
        expect(job.finished?).to be false
      end
    end
  end

  describe '::run' do
    let(:job) { spy(described_class)}

    before do
      allow(described_class).to receive(:new).and_return(job)
    end

    it 'creates, uploads, and runs the job via the SF API' do
      described_class.run(**args)
      expect(job).to have_received(:create)
      expect(job).to have_received(:upload)
      expect(job).to have_received(:run)
    end
  end

  describe '#run' do
    it 'PATCHs the job state to SF API to run the job' do
      subject.run
      expect(sfdc_client).to have_received(:patch).with("#{ingest_url}/#{id}", {state: described_class::STATES[:UploadComplete]}, anything)
    end
  end

  describe '#abort' do
    it 'PATCHs the job state to SF API to abort the job' do
      subject.abort
      expect(sfdc_client).to have_received(:patch).with("#{ingest_url}/#{id}", {state: described_class::STATES[:Aborted]}, anything)
    end
  end

  describe '#delete' do
    it 'DELETEs the job from SF API' do
      subject.delete
      expect(sfdc_client).to have_received(:delete).with("#{ingest_url}/#{id}")
    end
  end

  describe '#failed_results' do
    it 'GETs job info from SF API' do
      subject.failed_results
      expect(sfdc_client).to have_received(:get).with("#{ingest_url}/#{id}/failedResults/")
    end
  end

  describe '#successful_results' do
    it 'GETs successful results from SF API' do
      subject.successful_results
      expect(sfdc_client).to have_received(:get).with("#{ingest_url}/#{id}/successfulResults/")
    end
  end

  describe '#info' do
    it 'GETs job info from SF API' do
      subject.info
      expect(sfdc_client).to have_received(:get).with("#{ingest_url}/#{id}")
    end
  end

  describe '#upload' do
    it 'PUTs CSV to SF API to upload records to job' do
      subject.upload
      expect(sfdc_client).to have_received(:put).with(subject.content_url, anything, hash_including("Content-Type": 'text/csv'))
    end
  end

  describe '#create' do
    it 'POSTs to SF API to create a job' do
      subject.create
      expect(sfdc_client).to have_received(:post).with("#{ingest_url}/", hash_including(operation: operation, object: object))
    end
  end
end

