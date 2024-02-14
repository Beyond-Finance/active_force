require 'spec_helper'

module ActiveForce
  describe SObject do
    let(:client){ double "client" }

    before do
      ActiveForce.sfdc_client = client
    end

    describe '.select' do
      it 'has correct fields in query' do
        query = Territory.select(:name, :id)
        expect(query.fields).to eq(["Name", "Id"])
      end

      context 'when getting the value of an uninitialized attribute' do
        let(:territory) { Territory.select(:id).first }
        let(:response) do
          [build_restforce_sobject({
            "Id"       => "123",
            "Quota__c" => "321",
          })]
        end

        before do
          allow(client).to receive(:query).once.and_return response
        end

        it 'raises missing attribute error if uninitialized variable is called' do
          expect{territory.name}.to raise_error(ActiveModel::MissingAttributeError)
        end

        it 'returns SObjects with Uninitialized Value' do
          expect(territory.instance_variable_get(:@attributes)["name"]).to be_an_instance_of(ActiveModel::Attribute::UninitializedValue)
        end
      end
    end
  end
end
