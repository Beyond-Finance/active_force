require 'spec_helper'

describe ActiveForce::SObject do
  let(:sobject_hash) { YAML.load(fixture('sobject/single_sobject_hash')) }
  let(:client) { double 'Client' }

  before do
    ActiveForce.sfdc_client = client
  end

  describe ".new" do
    it 'should assigns values when are passed by parameters' do
      expect(Whizbang.new({ text: 'some text' }).text).to eq 'some text'
    end
  end

  describe ".build" do
    let(:sobject){ Whizbang.build sobject_hash }

    it "build a valid sobject from a JSON" do
      expect(sobject).to be_an_instance_of Whizbang
    end

    it "sets the values' types from the sf_type" do
      expect(sobject.boolean).to be_an_instance_of TrueClass
      expect(sobject.checkbox).to be_an_instance_of FalseClass
      expect(sobject.date).to be_an_instance_of Date
      expect(sobject.datetime).to be_an_instance_of Time
      expect(sobject.percent).to be_an_instance_of Float
      expect(sobject.text).to be_an_instance_of String
      expect(sobject.picklist_multiselect).to be_an_instance_of Array
    end
  end

  describe ".field" do
    it "add a mappings" do
      expect(Whizbang.mappings).to include(
        checkbox: 'Checkbox_Label',
        text: 'Text_Label',
        date: 'Date_Label',
        datetime: 'DateTime_Label',
        picklist_multiselect: 'Picklist_Multiselect_Label'
      )
    end

    it "set an attribute" do
      %w[checkbox text date datetime picklist_multiselect].each do |name|
        expect(Whizbang.attribute_names).to include(name)
      end
    end

    it "uses Salesforce API naming conventions by default" do
      expect(Whizbang.mappings[:estimated_close_date]).to eq 'Estimated_Close_Date__c'
    end

    describe 'having an id' do
      it 'has one by default' do
        expect(Territory.new).to respond_to(:id)
        expect(Territory.mappings[:id]).to eq 'Id'
      end

      it 'can be overridden' do
        expect(Quota.new).to respond_to(:id)
        expect(Quota.mappings[:id]).to eq 'Bar_Id__c'
      end
    end

    describe 'having a default value' do
      subject { Bangwhiz }

      context 'when using the default value' do
        let(:instantiation_attributes) { {name: 'some name'} }
        let(:percent) { 50.0 }

        it 'sends percent to salesforce' do
          expect(client).to receive(:create!)
                        .with(anything, hash_including('Percent_Label' => percent))
          subject.create(**instantiation_attributes)
        end

        it 'sets percent field upon object instantiation' do
          expect(subject.new(**instantiation_attributes)[:percent]).to eq(percent)
        end
      end

      context 'when overriding a default value' do
        let(:instantiation_attributes) { {name: 'some name', percent: percent} }
        let(:percent) { 25.0 }

        it 'sends percent to salesforce' do
          expect(client).to receive(:create!)
                        .with(anything, hash_including('Percent_Label' => percent))
          subject.create(**instantiation_attributes)
        end

        it 'sets percent field upon object instantiation' do
          expect(subject.new(**instantiation_attributes)[:percent]).to eq(percent)
        end

        context 'when the override to default value is the same as the default value' do
          let(:percent) { 50.0 }

          it 'sends percent to salesforce' do
            expect(client).to receive(:create!)
                          .with(anything, hash_including('Percent_Label' => percent))
            subject.create(**instantiation_attributes)
          end

          it 'sets percent field upon object instantiation' do
            expect(subject.new(**instantiation_attributes)[:percent]).to eq(percent)
          end
        end
      end
    end

    context 'as: :multipicklist' do
      before do
        class IceCream < ActiveForce::SObject
          field :flavors, as: :multipicklist
        end
        sundae.clear_changes_information
        sundae.flavors = %w(chocolate vanilla strawberry)
      end

      context 'mutation of multipicklist' do
        let(:sundae) { IceCream.new }

        before { sundae.clear_changes_information }

        it 'detects mutation' do
          sundae.flavors.delete('chocolate')
          expect(sundae.flavors_changed?).to be true
        end
      end

      context 'on create' do
        let(:sundae) { IceCream.new }
        it 'formats the picklist values' do
          expect(client).to receive(:create!).with('IceCream__c', {'Flavors__c' => 'chocolate;vanilla;strawberry'})
          sundae.save
        end
      end

      context 'on update' do
        let(:sundae) { IceCream.new(id: '1') }
        it 'formats the picklist values' do
          expect(client).to receive(:update!).with('IceCream__c', {'Flavors__c' => 'chocolate;vanilla;strawberry', 'Id' => '1'})
          sundae.save
        end
      end

    end
  end

  describe '.describe' do
    subject { Whizbang.describe }

    let(:describe_response) { { 'fields' => [] } }

    before do
      allow(client).to receive(:describe).and_return(describe_response)
    end

    it 'passes table_name to sfdc_client.describe' do
      subject
      expect(client).to have_received(:describe).with(Whizbang.table_name)
    end

    it 'returns response from describe' do
      expect(subject).to eq(describe_response)
    end
  end

  describe "CRUD" do
    let(:instance){ Whizbang.new(id: '1') }

    describe '#update' do

      context 'with valid attributes' do
        before do
          expected_args = [
            Whizbang.table_name,
            {'Text_Label' => 'some text', 'Boolean_Label' => false, 'Id' => '1', "Updated_From__c"=>"Rails"}
          ]
          expect(client).to receive(:update!).with(*expected_args).and_return('id')
        end

        it 'delegates to the Client with create! and sets the id' do
          expect(instance.update( text: 'some text', boolean: false )).to eq(true)
          expect(instance.text).to eq('some text')
        end
      end

      context 'with invalid attributes' do
        it 'sets the error on the instance' do
          expect(instance.update( boolean: true )).to eq(false)
          expect(instance.errors).to be_present
          expect(instance.errors.full_messages.count).to eq(1)
          expect(instance.errors.full_messages[0]).to eq("Percent can't be blank")
        end
      end
    end

    describe ".update!" do
      context 'with valid attributes' do
        describe 'and without a ClientError' do
          before do
            expected_args = [
              Whizbang.table_name,
              {'Text_Label' => 'some text', 'Boolean_Label' => false, 'Id' => '1', "Updated_From__c"=>"Rails"}
            ]
            expect(client).to receive(:update!).with(*expected_args).and_return('id')
          end
          it 'saves successfully' do
            expect(instance.update!( text: 'some text', boolean: false )).to eq(true)
            expect(instance.text).to eq('some text')
          end
        end

        describe 'and with a ClientError' do
          let(:faraday_error){ Faraday::ClientError.new('Some String') }

          before{ expect(client).to receive(:update!).and_raise(faraday_error) }

          it 'raises an error' do
            expect{ instance.update!( text: 'some text', boolean: false ) }.to raise_error(Faraday::ClientError)
          end
        end
      end

      context 'with invalid attributes' do
        let(:instance){ Whizbang.new boolean: true }

        it 'raises an error' do
          expect{ instance.update!( text: 'some text', boolean: true ) }.to raise_error(ActiveForce::RecordInvalid)
        end
      end
    end

    describe '#create' do
      context 'with valid attributes' do
        before do
          expect(client).to receive(:create!).and_return('id')
        end

        it 'delegates to the Client with create! and sets the id' do
          expect(instance.create).to be_instance_of(Whizbang)
          expect(instance.id).to eq('id')
        end
      end


      context 'with invalid attributes' do
        let(:instance){ Whizbang.new boolean: true }

        it 'sets the error on the instance' do
          expect(instance.create).to be_instance_of(Whizbang)
          expect(instance.id).to eq(nil)
          expect(instance.errors).to be_present
          expect(instance.errors.full_messages.count).to eq(1)
          expect(instance.errors.full_messages[0]).to eq("Percent can't be blank")
        end
      end
    end

    describe '#create!' do
      context 'with valid attributes' do
        describe 'and without a ClientError' do

          before{ expect(client).to receive(:create!).and_return('id') }

          it 'saves successfully' do
            expect(instance.create!).to be_instance_of(Whizbang)
            expect(instance.id).to eq('id')
          end
        end

        describe 'and with a ClientError' do
          let(:faraday_error){ Faraday::ClientError.new('Some String') }

          before{ expect(client).to receive(:create!).and_raise(faraday_error) }

          it 'raises an error' do
            expect{ instance.create! }.to raise_error(Faraday::ClientError)
          end
        end
      end

      context 'with invalid attributes' do
        let(:instance){ Whizbang.new boolean: true }

        it 'raises an error' do
          expect{ instance.create! }.to raise_error(ActiveForce::RecordInvalid)
        end
      end
    end

    describe "#destroy" do
      it "should send client :destroy! with its id" do
        expect(client).to receive(:destroy!).with 'Whizbang__c', '1'
        instance.destroy
      end
    end

    describe 'self.create' do
      before do
        expect(client).to receive(:create!)
          .with(Whizbang.table_name, { 'Text_Label' => 'some text', 'Updated_From__c' => 'Rails' })
          .and_return('id')
      end

      it 'should create a new instance' do
        expect(Whizbang.create(text: 'some text')).to be_instance_of(Whizbang)
      end
    end

    describe 'self.update' do
      it 'uses the client to update the correct record' do
        expect(client).to receive(:update!)
          .with(Whizbang.table_name, { 'Id' => '12345678', 'Text_Label' => 'my text', 'Updated_From__c' => 'Rails' })
          .and_return(true)
        Whizbang.update('12345678', text: 'my text')
      end

      it 'includes given nil values in the request' do
        allow(client).to receive(:update!).and_return(true)
        Whizbang.update('test123', text: nil, date: nil)
        expect(client).to have_received(:update!).with(
          Whizbang.table_name,
          { 'Id' => 'test123', 'Text_Label' => nil, 'Date_Label' => nil, 'Updated_From__c' => 'Rails' }
        )
      end
    end

    describe 'self.update!' do
      it 'uses the client to update the correct record' do
        expect(client).to receive(:update!)
          .with(Whizbang.table_name, { 'Id' => '123456789', 'Text_Label' => 'some other text', 'Updated_From__c' => 'Rails' })
          .and_return(true)
        Whizbang.update('123456789', text: 'some other text')
      end

      it 'includes given nil values in the request' do
        allow(client).to receive(:update!).and_return(true)
        Whizbang.update!('test123', text: nil, date: nil)
        expect(client).to have_received(:update!).with(
          Whizbang.table_name,
          { 'Id' => 'test123', 'Text_Label' => nil, 'Date_Label' => nil, 'Updated_From__c' => 'Rails' }
        )
      end
    end
  end

  describe '.count' do
    let(:response) { [Restforce::Mash.new(expr0: 1)] }

    before do
      allow(client).to receive(:query).and_return(response)
    end

    it 'sends the correct query to the client' do
      expected = 'SELECT count(Id) FROM Whizbang__c'
      Whizbang.count
      expect(client).to have_received(:query).with(expected)
    end

    it 'returns the result from the response' do
      expect(Whizbang.count).to eq(1)
    end

    it 'works with .where' do
      expected = 'SELECT count(Id) FROM Whizbang__c WHERE (Boolean_Label = true)'
      Whizbang.where(boolean: true).count
      expect(client).to have_received(:query).with(expected)
    end
  end

  describe '.sum' do
    let(:response) { [Restforce::Mash.new(expr0: 22)] }

    before do
      allow(client).to receive(:query).and_return(response)
    end

    it 'raises ArgumentError if given blank' do
      expect { Whizbang.sum(nil) }.to raise_error(ArgumentError, 'field is required')
    end

    it 'raises UnknownFieldError if given invalid field' do
      expect { Whizbang.sum(:invalid) }
        .to raise_error(ActiveForce::UnknownFieldError, /unknown field 'invalid' for Whizbang/i)
    end

    it 'sends the correct query to the client' do
      expected = 'SELECT sum(Percent_Label) FROM Whizbang__c'
      Whizbang.sum(:percent)
      expect(client).to have_received(:query).with(expected)
    end

    it 'works when given a string field' do
      expected = 'SELECT sum(Percent_Label) FROM Whizbang__c'
      Whizbang.sum('percent')
      expect(client).to have_received(:query).with(expected)
    end

    it 'returns the result from the response' do
      expect(Whizbang.sum(:percent)).to eq(22)
    end

    it 'works with .where' do
      expected = 'SELECT sum(Percent_Label) FROM Whizbang__c WHERE (Boolean_Label = true)'
      Whizbang.where(boolean: true).sum(:percent)
      expect(client).to have_received(:query).with(expected)
    end
  end

  describe "#find_by" do
    it "should query the client, with the SFDC field names and correctly enclosed values" do
      expect(client).to receive(:query).with("SELECT #{Whizbang.fields.join ', '} FROM Whizbang__c WHERE (Id = 123) AND (Text_Label = 'foo') LIMIT 1")
      Whizbang.find_by id: 123, text: "foo"
    end

    it 'raises UnknownFieldError if given invalid field' do
      expect { Whizbang.find_by(xyz: 1) }
        .to raise_error(ActiveForce::UnknownFieldError, /unknown field 'xyz' for Whizbang/)
    end
  end

  describe "#find_by!" do
    it "queries the client, with the SFDC field names and correctly enclosed values" do
      expect(client).to receive(:query).with("SELECT #{Whizbang.fields.join ', '} FROM Whizbang__c WHERE (Id = 123) AND (Text_Label = 'foo') LIMIT 1").and_return([Restforce::Mash.new(Id: 123, text: 'foo')])
      Whizbang.find_by! id: 123, text: "foo"
    end

    it "raises if nothing found" do
      expect(client).to receive(:query).with("SELECT #{Whizbang.fields.join ', '} FROM Whizbang__c WHERE (Id = 123) AND (Text_Label = 'foo') LIMIT 1")
      expect { Whizbang.find_by! id: 123, text: "foo" }.to raise_error(ActiveForce::RecordNotFound)
    end

    it 'raises UnknownFieldError if given invalid field' do
      expect { Whizbang.find_by!(xyz: 1) }
        .to raise_error(ActiveForce::UnknownFieldError, /unknown field 'xyz' for Whizbang/)
    end
  end

  describe '.find!' do
    let(:id) { 'abc123' }

    before do
      allow(client).to receive(:query)
    end

    it 'returns found record' do
      query = "SELECT #{Whizbang.fields.join ', '} FROM Whizbang__c WHERE (Id = '#{id}') LIMIT 1"
      expected = Restforce::Mash.new(Id: id)
      allow(client).to receive(:query).with(query).and_return([expected])
      actual = Whizbang.find!(id)
      expect(actual.id).to eq(expected.Id)
    end

    it 'raises RecordNotFound if nothing found' do
      expect { Whizbang.find!(id) }
        .to raise_error(ActiveForce::RecordNotFound, "Couldn't find #{Whizbang.table_name} with id #{id}")
    end
  end

  describe '#reload' do
    let(:client) do
      double("sfdc_client", query: [Restforce::Mash.new(Id: 1, Name: 'Jeff')])
    end
    let(:quota){ Quota.new(id: '1') }
    let(:territory){ Territory.new(id: '1', quota_id: '1') }

    before do
      ActiveForce.sfdc_client = client
    end

    it 'clears cached associations' do
      soql = "SELECT Id, Bar_Id__c FROM Quota__c WHERE (Id = '1') LIMIT 1"
      expect(client).to receive(:query).twice.with soql
      allow(Territory).to receive(:find){ territory }
      territory.quota
      territory.quota
      territory.reload
      territory.quota
    end

    it "refreshes the object's attributes" do
      territory.name = 'Walter'
      expect(territory.name).to eq 'Walter'
      territory.reload
      expect(territory.name).to eq 'Jeff'
      expect(territory.changed_attributes).to be_empty
    end

    it 'returns the same object' do
      allow(Territory).to receive(:find){ Territory.new }
      expected = territory
      expect(territory.reload).to eql expected
    end
  end

  describe '#persisted?' do
    context 'with an id' do
      let(:instance){ Territory.new(id: '00QV0000004jeqNMAT') }

      it 'returns true' do
        expect(instance).to be_persisted
      end
    end

    context 'without an id' do
      let(:instance){ Territory.new }

      it 'returns false' do
        expect(instance).to_not be_persisted
      end
    end
  end

  describe 'logger output' do
    let(:instance){ Whizbang.new }

    before do
      allow(instance).to receive(:create!).and_raise(Faraday::ClientError.new(double))
    end

    it 'catches and logs the error' do
      expect(instance).to receive(:logger_output).and_return(false)
      instance.save
    end
  end

  describe 'to_json' do
    let(:instance) { Whizbang.new }

    it 'responds to' do
      expect(instance).to respond_to(:to_json)
    end
  end

  describe 'as_json' do
    let(:instance) { Whizbang.new }

    it 'responds to' do
      expect(instance).to respond_to(:as_json)
    end
  end

  describe ".save!" do
    let(:instance){ Whizbang.new }

    context 'with valid attributes' do
      describe 'and without a ClientError' do
        before{ expect(client).to receive(:create!).and_return('id') }
        it 'saves successfully' do
          expect(instance.save!).to eq(true)
        end
      end

      describe 'and with a ClientError' do
        let(:faraday_error){ Faraday::ClientError.new('Some String') }

        before{ expect(client).to receive(:create!).and_raise(faraday_error) }

        it 'raises an error' do
          expect{ instance.save! }.to raise_error(Faraday::ClientError)
        end
      end
    end

    context 'with invalid attributes' do
      let(:instance){ Whizbang.new boolean: true }

      it 'raises an error' do
        expect{ instance.save! }.to raise_error(ActiveForce::RecordInvalid)
      end
    end
  end

  describe '#[]' do
    let(:sobject){ Whizbang.build sobject_hash }

    it 'allows accessing the attribute values as if the Sobject were a Hash' do
      expect(sobject[:boolean]).to eq sobject.boolean
      expect(sobject[:checkbox]).to eq sobject.checkbox
      expect(sobject[:date]).to eq sobject.date
      expect(sobject[:datetime]).to eq sobject.datetime
      expect(sobject[:percent]).to eq sobject.percent
      expect(sobject[:text]).to eq sobject.text
      expect(sobject[:picklist_multiselect]).to eq sobject.picklist_multiselect
    end
  end

  describe '#[]=' do
    let(:sobject){ Whizbang.new }

    it 'allows modifying the attribute values as if the Sobject were a Hash' do
      expect(sobject[:boolean]=false).to eq sobject.boolean
      expect(sobject[:checkbox]=true).to eq sobject.checkbox
      expect(sobject[:datetime]=Time.now).to eq sobject.datetime
      expect(sobject[:percent]=50).to eq sobject.percent
      expect(sobject[:text]='foo-bar').to eq sobject.text
      sobject[:picklist_multiselect]='a;b'
      expect(sobject.picklist_multiselect).to eq ['a', 'b']
    end
  end

  describe ".save" do
    let(:instance){ Whizbang.new }

    context 'with valid attributes' do
      describe 'and without a ClientError' do
        before{ expect(client).to receive(:create!).and_return('id') }
        it 'saves successfully' do
          expect(instance.save).to eq(true)
        end
      end

      describe 'and with a ClientError' do
        let(:faraday_error){ Faraday::ClientError.new('Some String') }
        before{ expect(client).to receive(:create!).and_raise(faraday_error) }
        it 'returns false' do
          expect(instance.save).to eq(false)
        end
        it 'sets the error on the instance' do
          instance.save
          expect(instance.errors).to be_present
          expect(instance.errors.full_messages.count).to eq(1)
          expect(instance.errors.full_messages[0]).to eq('Some String')
        end
      end
    end

    context 'with invalid attributes' do
      let(:instance){ Whizbang.new boolean: true }

      it 'does not save' do
        expect(instance.save).to eq(false)
      end

      it 'sets the error on the instance' do
        instance.save
        expect(instance.errors).to be_present
        expect(instance.errors.full_messages.count).to eq(1)
        expect(instance.errors.full_messages[0]).to eq("Percent can't be blank")
      end
    end
  end
end
