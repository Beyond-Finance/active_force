# frozen_string_literal: true

require 'spec_helper'
require 'active_force/composite/tree_sender'

describe ActiveForce::SObject do
  let(:sobject_hash) { YAML.load(fixture('sobject/single_sobject_hash')) }
  let(:api_version) { '50.0' }
  let(:client) { instance_double(Restforce::Client, options: { api_version: api_version }) }

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

    describe '.create_tree' do
      let!(:sender_mock) do
        instance_double(ActiveForce::Composite::TreeSender, add_roots: [], send_trees: nil).tap do |mock|
          allow(ActiveForce::Composite::TreeSender).to receive(:new).and_return(mock)
        end
      end

      context 'when given single object' do
        it 'adds object to sender' do
          object = Whizbang.new
          Whizbang.create_tree(object)
          expect(sender_mock).to have_received(:add_roots).with(object)
        end
      end

      context 'when given array of objects' do
        it 'adds all objects to sender' do
          objects = [Whizbang.new, Whizbang.new]
          Whizbang.create_tree(objects)
          expect(sender_mock).to have_received(:add_roots).with(*objects)
        end
      end

      it 'calls send_trees on sender' do
        Whizbang.create_tree(Whizbang.new)
        expect(sender_mock).to have_received(:send_trees)
      end

      it 'allow_multiple_requests is false by default' do
        Whizbang.create_tree(Whizbang.new)
        expect(ActiveForce::Composite::TreeSender)
          .to have_received(:new).with(Whizbang, allow_multiple_requests: false)
      end

      it 'passes allow_multiple_requests to sender' do
        Whizbang.create_tree(Whizbang.new, allow_multiple_requests: true)
        expect(ActiveForce::Composite::TreeSender)
          .to have_received(:new).with(Whizbang, allow_multiple_requests: true)
      end
    end

    describe '.create_tree!' do
      let!(:sender_mock) do
        instance_double(ActiveForce::Composite::TreeSender, add_roots: [], send_trees!: nil).tap do |mock|
          allow(ActiveForce::Composite::TreeSender).to receive(:new).and_return(mock)
        end
      end

      context 'when given single object' do
        it 'adds object to sender' do
          object = Whizbang.new
          Whizbang.create_tree!(object)
          expect(sender_mock).to have_received(:add_roots).with(object)
        end
      end

      context 'when given array of objects' do
        it 'adds all objects to sender' do
          objects = [Whizbang.new, Whizbang.new]
          Whizbang.create_tree!(objects)
          expect(sender_mock).to have_received(:add_roots).with(*objects)
        end
      end

      it 'calls send_trees! on sender' do
        Whizbang.create_tree!(Whizbang.new)
        expect(sender_mock).to have_received(:send_trees!)
      end

      it 'allow_multiple_requests is false by default' do
        Whizbang.create_tree!(Whizbang.new)
        expect(ActiveForce::Composite::TreeSender)
          .to have_received(:new).with(Whizbang, allow_multiple_requests: false)
      end

      it 'passes allow_multiple_requests to sender' do
        Whizbang.create_tree!(Whizbang.new, allow_multiple_requests: true)
        expect(ActiveForce::Composite::TreeSender)
          .to have_received(:new).with(Whizbang, allow_multiple_requests: true)
      end
    end

    describe 'having an default value' do
      it 'uses the default value' do
        expect(Bangwhiz.new[:percent]).to eq(50.0)
      end

      it 'can be overridden' do
        expect(Bangwhiz.new(percent: 25.0)[:percent]).to eq(25.0)
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
  end

  describe "#count" do
    let(:count_response){ [Restforce::Mash.new(expr0: 1)] }

    it "responds to count" do
      expect(Whizbang).to respond_to(:count)
    end

    it "sends the query to the client" do
      expect(client).to receive(:query).and_return(count_response)
      expect(Whizbang.count).to eq(1)
    end

  end

  describe "#find_by" do
    it "should query the client, with the SFDC field names and correctly enclosed values" do
      expect(client).to receive(:query).with("SELECT #{Whizbang.fields.join ', '} FROM Whizbang__c WHERE (Id = 123) AND (Text_Label = 'foo') LIMIT 1")
      Whizbang.find_by id: 123, text: "foo"
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

  describe '#save_request' do
    let(:object) { Whizbang.new }
    let(:base_url) { "/services/data/sobjects/v#{api_version}/#{Whizbang.table_name}" }

    context 'when not persisted' do
      it 'has POST method' do
        expect(object.save_request.fetch(:method)).to eq('POST')
      end

      it 'does not include id in url' do
        expect(object.save_request.fetch(:url)).to eq(base_url)
      end

      it 'does not include id in body' do
        expect(object.save_request.fetch(:body).keys).not_to include('Id')
      end

      it 'includes all and only updated fields in body' do
        object.text = 'test_text'
        object.boolean = true
        expect(object.save_request.fetch(:body)).to eq({ 'Text_Label' => 'test_text', 'Boolean_Label' => true })
      end
    end

    context 'when persisted' do
      let(:id) { 'test_id' }

      before { object.id = id }

      it 'has PATCH method' do
        expect(object.save_request.fetch(:method)).to eq('PATCH')
      end

      it 'includes id in url' do
        expect(object.save_request.fetch(:url)).to eq("#{base_url}/#{id}")
      end

      it 'includes Id and all and only updated fields in body' do
        object.text = 'test_text'
        object.boolean = true
        expect(object.save_request.fetch(:body))
          .to eq({ 'Text_Label' => 'test_text', 'Boolean_Label' => true, 'Id' => id })
      end
    end
  end
end
