require 'spec_helper'

describe ActiveForce::Bulk::JobResult do
  subject { described_class.new(job: job)}
  let(:job) { instance_double(ActiveForce::Bulk::Job)}

  let(:failed_results_response) do
    Faraday::Response.new(status: 200, response_body: "\"sf__Id\",\"sf__Error\"")
  end

  let(:successful_results_response) do
    Faraday::Response.new(status: 200, response_body: "\"sf__Id\",\"sf__Error\"\n\"12354\",\"false\"\n")
  end

  let(:info) do
    {"id"=>"22222222222222",
      "operation"=>"update",
      "object"=>"FooBar__c",
      "createdById"=>"11111111111111111",
      "createdDate"=>"2023-09-22T16:39:09.000+0000",
      "systemModstamp"=>"2023-09-22T16:39:13.000+0000",
      "state"=>"JobComplete",
      "concurrencyMode"=>"Parallel",
      "contentType"=>"CSV",
      "apiVersion"=>58.0,
      "jobType"=>"V2Ingest",
      "lineEnding"=>"LF",
      "columnDelimiter"=>"COMMA",
      "numberRecordsProcessed"=>1,
      "numberRecordsFailed"=>0,
      "retries"=>0,
      "totalProcessingTime"=>713,
      "apiActiveProcessingTime"=>323,
      "apexProcessingTime"=>3}
  end

  let(:job_info_response) do
    Faraday::Response.new(status: 200, response_body: info)
  end

  before do
    allow(job).to receive(:failed_results).and_return(failed_results_response)
    allow(job).to receive(:successful_results).and_return(successful_results_response)
    allow(job).to receive(:info).and_return(job_info_response)
  end

  describe '::new' do
    it 'uses the passed in job object to pull job info' do
      expect(subject.stats[:total_processing_time]).to eq info['totalProcessingTime']
      expect(subject.stats[:number_records_processed]).to eq info['numberRecordsProcessed']
      expect(subject.stats[:number_records_failed]).to eq info['numberRecordsFailed']
      expect(subject.failed).to be_empty
      expect(subject.successful.size).to eq 1
    end
  end

  describe 'success?' do
    context 'when no failed results' do
      it 'returns true' do
        expect(subject.success?).to be true
      end
    end
    context 'when there are failed results' do
      it 'returns false' do
        subject.instance_variable_set(:@failed, [1])
        expect(subject.success?).to be false
      end
    end
  end
end

