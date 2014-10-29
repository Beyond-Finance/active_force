require 'spec_helper'

describe ActiveForce::SObject do
  let(:client) { double 'Client', create!: 'id' }

  before do
    ActiveForce.sfdc_client = client
  end

  describe "save" do
    it 'call action callback when save a record' do
      whizbanged = Whizbang.new
      whizbanged.save
      expect(whizbanged.updated_from).to eq 'Rails'
      expect(whizbanged.dirty_attribute).to eq true
      expect(whizbanged.changed.include? 'dirty_attribute').to eq true
      expect(whizbanged.changed.include? 'updated_from').to eq false
    end
  end
end
