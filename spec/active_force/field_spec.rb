require 'spec_helper'

describe ActiveForce::Field do
  let(:field) { ActiveForce::Field }

  describe 'initialize' do
    let(:some_field) { field.new(:some_field) }

    it 'should set "from" and "as" as default' do
      expect(some_field.sfdc_name).to eq 'Some_Field__c'
      expect(some_field.as).to eq :string
    end

    it 'should take values from the option parameter' do
      other_field = field.new(:other_field, sfdc_name: 'OT__c', as: :integer)
      expect(other_field.sfdc_name).to eq 'OT__c'
      expect(other_field.as).to eq :integer
    end
  end

  describe 'when the field is' do
    it 'a multipick should return all values as 1 string separated with ";"' do
      names = field.new(:names, as: :multipicklist)
      expect(names.value_for_hash ['olvap', 'eloy']).to eq 'olvap;eloy'
    end

    it 'a datetime should return a string like "YYYY-MM-DDTHH:MM:SSZ"' do
      current_time = DateTime.now
      names = field.new(:time, as: :datetime)
      expect(names.value_for_hash current_time).to eq current_time.to_fs(:iso8601)
    end
  end
end
