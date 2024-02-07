require 'spec_helper'

module ActiveForce
  describe SObject do
    let(:client){ double "client" }

    before do
      ActiveForce.sfdc_client = client
    end

    describe '.select' do
      it 'query has correct fields' do
        query = Territory.select(:name, :id)
        expect(query.fields).to eq(["Name", "Id"])
      end

      it 'returns SObjects with Uninitialized Value' do
        response = [build_restforce_sobject({
          "Id"       => "123",
          "Quota__c" => "321",
        })]
        allow(client).to receive(:query).once.and_return response
        territory = Territory.select(:id).first
        expect(territory.instance_variable_get(:@attributes)["name"]).to be_an_instance_of(ActiveModel::Attribute::UninitializedValue)
      end

      it 'raises missing attribute error if uninitialized variable is called' do
        response = [build_restforce_sobject({
          "Id"       => "123",
          "Quota__c" => "321",
        })]
        allow(client).to receive(:query).once.and_return response
        territory = Territory.select(:id).first

        expect{territory.name}.to raise_error(ActiveModel::MissingAttributeError)
      end
    end
  end
end
