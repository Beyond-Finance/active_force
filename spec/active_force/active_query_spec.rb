require 'spec_helper'

describe ActiveForce::ActiveQuery do
  let(:sobject) do
    double("sobject", {
      table_name: "table_name",
      fields: [],
      mappings: mappings
    })
  end
  let(:mappings){ { id: "Id", field: "Field__c", other_field: "Other_Field" } }
  let(:client) { double('client', query: nil) }
  let(:active_query){ described_class.new(sobject) }
  let(:api_result) do
    [
      {"Id" => "0000000000AAAAABBB"},
      {"Id" => "0000000000CCCCCDDD"}
    ]
  end

  before do
    allow(active_query).to receive(:sfdc_client).and_return client
    allow(active_query).to receive(:build).and_return Object.new
  end

  describe "to_a" do
    before do
      expect(client).to receive(:query).and_return(api_result)
    end

    it "should return an array of objects" do
      result = active_query.where("Text_Label = 'foo'").to_a
      expect(result).to be_a Array
    end

    it "should decorate the array of objects" do
      expect(sobject).to receive(:decorate)
      active_query.where("Text_Label = 'foo'").to_a
    end
  end

  describe '#blank? delegation' do
    before do
      allow(client).to receive(:query).and_return(api_result)
    end

    context 'when there are no records' do
      let(:api_result) { [] }

      it 'returns true' do
        result = active_query.where("Text_Label = 'foo'").blank?
        expect(result).to be true
      end
    end

    context 'when records are returned' do
      it 'returns false' do
        result = active_query.where("Text_Label = 'foo'").blank?
        expect(result).to be false
      end
    end
  end

  describe '#present? delegation' do
    before do
      allow(client).to receive(:query).and_return(api_result)
    end

    context 'when there are no records' do
      let(:api_result) { [] }

      it 'returns false' do
        result = active_query.where("Text_Label = 'foo'").present?
        expect(result).to be false
      end
    end

    context 'when there are records' do
      it 'returns true' do
        result = active_query.where("Text_Label = 'foo'").present?
        expect(result).to be true
      end
    end
  end

  describe '#any? delegation' do
    before do
      allow(client).to receive(:query).and_return(api_result)
    end

    context 'when there are no records' do
      let(:api_result) { [] }

      it 'returns true' do
        result = active_query.where("Text_Label = 'foo'").any?
        expect(result).to be false
      end
    end

    context 'when records are returned' do
      it 'returns false' do
        result = active_query.where("Text_Label = 'foo'").any?
        expect(result).to be true
      end
    end
  end

  describe "select only some field using mappings" do
    it "should return a query only with selected field" do
      new_query = active_query.select(:field)
      expect(new_query.to_s).to eq("SELECT Field__c FROM table_name")
    end
  end

  describe "condition mapping" do
    it "maps conditions for a .where" do
      new_query = active_query.where(field: 123)
      expect(new_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = 123)")
    end

    it 'transforms an array to a WHERE/IN clause' do
      new_query = active_query.where(field: ['foo', 'bar'])
      expect(new_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c IN ('foo','bar'))")
    end

    it "encloses the value in quotes if it's a string" do
      new_query = active_query.where field: "hello"
      expect(new_query.to_s).to end_with("(Field__c = 'hello')")
    end

    it "formats as YYYY-MM-DDThh:mm:ss-hh:mm and does not enclose in quotes if it's a DateTime" do
      value = DateTime.now
      expect(active_query.where(field: value).to_s).to end_with("(Field__c = #{value.iso8601})")
    end

    it "formats as YYYY-MM-DDThh:mm:ss-hh:mm and does not enclose in quotes if it's a Time" do
      value = Time.now
      expect(active_query.where(field: value).to_s).to end_with("(Field__c = #{value.iso8601})")
    end

    it "formats as YYYY-MM-DD and does not enclose in quotes if it's a Date" do
      value = Date.today
      expect(active_query.where(field: value).to_s).to end_with("(Field__c = #{value.iso8601})")
    end

    it "puts NULL when a field is set as nil" do
      new_query = active_query.where field: nil
      expect(new_query.to_s).to end_with("(Field__c = NULL)")
    end

    describe 'bind parameters' do
      let(:mappings) do
        super().merge({
          other_field: 'Other_Field__c',
          name: 'Name'
        })
      end

      it 'accepts bind parameters' do
        new_query = active_query.where('Field__c = ?', 123)
        expect(new_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = 123)")
      end

      it 'accepts nil bind parameters' do
        new_query = active_query.where('Field__c = ?', nil)
        expect(new_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = NULL)")
      end

      it 'accepts multiple bind parameters' do
        new_query = active_query.where('Field__c = ? AND Other_Field__c = ? AND Name = ?', 123, 321, 'Bob')
        expect(new_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = 123 AND Other_Field__c = 321 AND Name = 'Bob')")
      end

      it 'formats as YYYY-MM-DDThh:mm:ss-hh:mm and does not enclose in quotes if value is a DateTime' do
        value = DateTime.now
        expect(active_query.where('Field__c > ?', value).to_s).to end_with("(Field__c > #{value.iso8601})")
      end

      it 'formats as YYYY-MM-DDThh:mm:ss-hh:mm and does not enclose in quotes if value is a Time' do
        value = Time.now
        expect(active_query.where('Field__c > ?', value).to_s).to end_with("(Field__c > #{value.iso8601})")
      end

      it 'formats as YYYY-MM-DD and does not enclose in quotes if value is a Date' do
        value = Date.today
        expect(active_query.where('Field__c > ?', value).to_s).to end_with("(Field__c > #{value.iso8601})")
      end

      it 'complains when there given an incorrect number of bind parameters' do
        expect{
          active_query.where('Field__c = ? AND Other_Field__c = ? AND Name = ?', 123, 321)
        }.to raise_error(ActiveForce::PreparedStatementInvalid, 'wrong number of bind variables (2 for 3)')
      end

      context 'named bind parameters' do
        it 'accepts bind parameters' do
          new_query = active_query.where('Field__c = :field', field: 123)
          expect(new_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = 123)")
        end

        it 'accepts nil bind parameters' do
          new_query = active_query.where('Field__c = :field', field: nil)
          expect(new_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = NULL)")
        end

        it 'formats as YYYY-MM-DDThh:mm:ss-hh:mm and does not enclose in quotes if value is a DateTime' do
          value = DateTime.now
          new_query = active_query.where('Field__c < :field', field: value)
          expect(new_query.to_s).to end_with("(Field__c < #{value.iso8601})")
        end

        it 'formats as YYYY-MM-DDThh:mm:ss-hh:mm and does not enclose in quotes if value is a Time' do
          value = Time.now
          new_query = active_query.where('Field__c < :field', field: value)
          expect(new_query.to_s).to end_with("(Field__c < #{value.iso8601})")
        end

        it 'formats as YYYY-MM-DD and does not enclose in quotes if value is a Date' do
          value = Date.today
          new_query = active_query.where('Field__c < :field', field: value)
          expect(new_query.to_s).to end_with("(Field__c < #{value.iso8601})")
        end

        it 'accepts multiple bind parameters' do
          new_query = active_query.where('Field__c = :field AND Other_Field__c = :other_field AND Name = :name', field: 123, other_field: 321, name: 'Bob')
          expect(new_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = 123 AND Other_Field__c = 321 AND Name = 'Bob')")
        end

        it 'accepts multiple bind parameters orderless' do
          new_query = active_query.where('Field__c = :field AND Other_Field__c = :other_field AND Name = :name', name: 'Bob', other_field: 321, field: 123)
          expect(new_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = 123 AND Other_Field__c = 321 AND Name = 'Bob')")
        end

        it 'complains when there given an incorrect number of bind parameters' do
          expect{
            active_query.where('Field__c = :field AND Other_Field__c = :other_field AND Name = :name', field: 123, other_field: 321)
          }.to raise_error(ActiveForce::PreparedStatementInvalid, 'missing value for :name in Field__c = :field AND Other_Field__c = :other_field AND Name = :name')
        end
      end
    end
  end

  describe '#where' do
    before do
      allow(client).to receive(:query).with("SELECT Id FROM table_name WHERE (Text_Label = 'foo')").and_return(api_result1)
      allow(client).to receive(:query).with("SELECT Id FROM table_name WHERE (Text_Label = 'foo') AND (Checkbox_Label = true)").and_return(api_result2)
    end
    let(:api_result1) do
      [
        {"Id" => "0000000000AAAAABBB"},
        {"Id" => "0000000000CCCCCDDD"},
        {"Id" => "0000000000EEEEEFFF"}
      ]
    end
    let(:api_result2) do
      [
        {"Id" => "0000000000EEEEEFFF"}
      ]
    end

    it 'allows method chaining' do
      result = active_query.where("Text_Label = 'foo'").where("Checkbox_Label = true")
      expect(result).to be_a described_class
    end

    it 'does not execute a query' do
      active_query.where('x')
      expect(client).not_to have_received(:query)
    end

    context 'when calling `where` on an ActiveQuery object that already has records' do
      context 'after the query result has been decorated' do
        it 'returns a new ActiveQuery object' do
          first_active_query = active_query.where("Text_Label = 'foo'")
          first_active_query.to_a # decorates the results
          second_active_query = first_active_query.where("Checkbox_Label = true")
          second_active_query.to_a
          expect(second_active_query).to be_a described_class
          expect(second_active_query).not_to eq first_active_query
          expect(second_active_query.to_s).not_to eq first_active_query.to_s
          expect(second_active_query.to_a.size).to eq(1)
        end
      end
    end

    context 'when calling `where` on an ActiveQuery object that already has records' do
      context 'without the query result being decorated' do

        it 'returns a new ActiveQuery object' do
          first_active_query = active_query.where("Text_Label = 'foo'")
          second_active_query = first_active_query.where("Checkbox_Label = true")
          expect(second_active_query).to be_a described_class
          expect(second_active_query).not_to eq first_active_query
          expect(second_active_query.to_s).not_to eq first_active_query.to_s
          expect(second_active_query.to_a.size).to eq(1)
        end
      end
    end

    context 'when given attributes Hash with fields that do not exist on the SObject' do
      it 'uses the given key in an eq condition' do
        expected = 'SELECT Id FROM table_name WHERE (no_attribute = 1) AND (another_one = 2)'
        expect(active_query.where(no_attribute: 1, 'another_one' => 2).to_s).to eq(expected)
      end

      it 'uses the given key in an in condition' do
        expected = 'SELECT Id FROM table_name WHERE (no_attribute IN (1,2))'
        expect(active_query.where(no_attribute: [1, 2]).to_s).to eq(expected)
      end
    end
  end

  describe '#not' do
    it 'adds a not condition' do
      expect(active_query.not(field: 'x').to_s).to end_with("WHERE (NOT ((Field__c = 'x')))")
    end

    it 'allows chaining' do
      expect(active_query.where(field: 'x').not(field: 'y').where(field: 'z')).to be_a(described_class)
    end

    it 'does not mutate the original query' do
      original = active_query.to_s
      active_query.not(field: 'x')
      expect(active_query.to_s).to eq(original)
    end

    it 'returns the original query if not given a condition' do
      expect(active_query.not).to be(active_query)
    end

    it 'does not execute a query' do
      active_query.not(field: 'x')
      expect(client).not_to have_received(:query)
    end
  end

  describe "#find_by" do
    it "should query the client, with the SFDC field names and correctly enclosed values" do
      expect(client).to receive(:query).with("SELECT Id FROM table_name WHERE (Field__c = 123) LIMIT 1")
      new_query = active_query.find_by field: 123
      expect(new_query).to be_nil
    end
  end

  describe '#find_by!' do
    it 'raises if record not found' do
      allow(client).to receive(:query).and_return(build_restforce_collection)
      expect { active_query.find_by!(field: 123) }
        .to raise_error(ActiveForce::RecordNotFound, "Couldn't find #{sobject.table_name} with {:field=>123}")
    end
  end

  describe '#find!' do
    let(:id) { 'test_id' }

    before do
      allow(client).to receive(:query).and_return(build_restforce_collection([{ 'Id' => id }]))
    end

    it 'queries for single record by given id' do
      active_query.find!(id)
      expect(client).to have_received(:query).with("SELECT Id FROM #{sobject.table_name} WHERE (Id = '#{id}') LIMIT 1")
    end

    context 'when record is found' do
      let(:record) { build_restforce_sobject(id: id) }

      before do
        allow(active_query).to receive(:build).and_return(record)
      end

      it 'returns the record' do
        expect(active_query.find!(id)).to eq(record)
      end
    end

    context 'when no record is found' do
      before do
        allow(client).to receive(:query).and_return(build_restforce_collection)
      end

      it 'raises RecordNotFound' do
        expect { active_query.find!(id) }
          .to raise_error(ActiveForce::RecordNotFound, "Couldn't find #{sobject.table_name} with id #{id}")
      end
    end
  end

  describe "responding as an enumerable" do
    before do
      expect(active_query).to receive(:to_a).and_return([])
    end

    it "should call to_a when receiving each" do
      active_query.each {}
    end

    it "should call to_a when receiving map" do
      active_query.map {}
    end
  end

  describe "prevent SOQL injection attacks" do
    let(:mappings){ { quote_field: "QuoteField", backslash_field: "Backslash_Field__c", number_field: "NumberField" } }
    let(:quote_input){ "' OR Id!=NULL OR Id='" }
    let(:backslash_input){ "\\" }
    let(:number_input){ 123 }
    let(:expected_query){ "SELECT Id FROM table_name WHERE (Backslash_Field__c = '\\\\' AND NumberField = 123 AND QuoteField = '\\' OR Id!=NULL OR Id=\\'')" }

    it 'escapes quotes and backslashes in bind parameters' do
      new_query = active_query.where('Backslash_Field__c = :backslash_field AND NumberField = :number_field AND QuoteField = :quote_field', number_field: number_input, backslash_field: backslash_input, quote_field: quote_input)
      expect(new_query.to_s).to eq(expected_query)
    end

    it 'escapes quotes and backslashes in named bind parameters' do
      new_query = active_query.where('Backslash_Field__c = ? AND NumberField = ? AND QuoteField = ?', backslash_input, number_input, quote_input)
      expect(new_query.to_s).to eq(expected_query)
    end

    it 'escapes quotes and backslashes in hash conditions' do
      new_query = active_query.where(backslash_field: backslash_input, number_field: number_input, quote_field: quote_input)
      expect(new_query.to_s).to eq("SELECT Id FROM table_name WHERE (Backslash_Field__c = '\\\\') AND (NumberField = 123) AND (QuoteField = '\\' OR Id!=NULL OR Id=\\'')")
    end
  end

  describe '#none' do
    it 'returns a query with a where clause that is impossible to satisfy' do
      expect(active_query.none.to_s).to eq "SELECT Id FROM table_name WHERE (Id = '111111111111111111') AND (Id = '000000000000000000')"
    end

    it 'does not query the API' do
      expect(client).to_not receive :query
      active_query.none.to_a
    end
  end

  describe '#loaded?' do
    subject { active_query.loaded? }

    before do
      active_query.instance_variable_set(:@records, records)
    end

    context 'when there are records loaded in memory' do
      let(:records) { nil }

      it { is_expected.to be_falsey }
    end

    context 'when there are records loaded in memory' do
      let(:records) { [build_restforce_sobject(id: 1)] }

      it { is_expected.to be_truthy }
    end
  end

  describe "#order" do
    context 'when it is symbol' do 
      it "should add an order condition with actual SF field name" do
        expect(active_query.order(:field).to_s).to eq "SELECT Id FROM table_name ORDER BY Field__c"
      end
    end

    context 'when it is string - raw soql' do
      it "should add an order condition same as the string provided" do
        expect(active_query.order('Field__c').to_s).to eq "SELECT Id FROM table_name ORDER BY Field__c"
      end
    end

   context 'when it is multiple columns' do
    it "should add an order condition with actual SF field name and the provided order type" do
      expect(active_query.order(:other_field, field: :desc).to_s).to eq "SELECT Id FROM table_name ORDER BY Other_Field, Field__c DESC"
    end
   end
    
  end

  describe '#first' do
    before do
      allow(client).to receive(:query).and_return(api_result)
      api_result.each do |instance|
        allow(active_query).to receive(:build).with(instance, {}).and_return(double(:sobject, id: instance['Id']))
      end
    end

    it 'returns a single record when the api was already queried' do
      active_query.to_a # this will simulate the api call as to_a executes the query and populates the records
      expect(active_query.first.id).to eq("0000000000AAAAABBB")
    end

    it 'returns a single record when the api was not already queried' do
      expect(active_query.first.id).to eq("0000000000AAAAABBB")
    end
  end
end
