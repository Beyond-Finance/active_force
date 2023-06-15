# frozen_string_literal: true

require 'spec_helper'

module ActiveForce
  RSpec.describe SObject do
    let(:client) { instance_double(Restforce::Client, query: []) }

    before do
      ActiveForce.sfdc_client = client
    end

    describe '#traversable_root?' do
      it 'is true if object does not have any belongs_to associations' do
        object = CompositeSupport::Root.new
        expect(object.traversable_root?).to be(true)
      end

      it 'is true if object has belongs_to associations but none are loaded' do
        object = CompositeSupport::Parent.new
        expect(object.traversable_root?).to be(true)
      end

      it 'is true if object has loaded belongs_to association but it is empty' do
        object = CompositeSupport::Parent.new(id: 'x')
        object.root
        expect(object.traversable_root?).to be(true)
      end

      it 'is false if object has loaded belongs_to associations with value' do
        object = CompositeSupport::Parent.new(id: 'x')
        object.root = CompositeSupport::Root.new
        expect(object.traversable_root?).to be(false)
      end
    end

    describe '#traversable_parents' do
      it 'is empty if object does not have any belongs_to associations' do
        object = CompositeSupport::Root.new
        expect(object.traversable_parents).to be_empty
      end

      it 'is empty if object has belongs_to associations but none are loaded' do
        object = CompositeSupport::Parent.new
        expect(object.traversable_parents).to be_empty
      end

      it 'is empty if object has loaded belongs_to association but it is empty' do
        object = CompositeSupport::Parent.new(id: 'x')
        object.root
        expect(object.traversable_parents).to be_empty
      end

      it 'contains relationship name and value of each loaded belongs_to association' do
        child = CompositeSupport::Child.new
        other_child = CompositeSupport::OtherChild.new
        leaf = CompositeSupport::Leaf.new
        leaf.child = child
        leaf.other_child = other_child
        expected = { 'Child_Id__r' => [child], 'OtherChild_Id__r' => [other_child] }
        expect(leaf.traversable_parents.transform_values(&:objects)).to eq(expected)
      end

      it 'combines values if associations have the same relationship name' do
        child = CompositeSupport::Child.new
        alt_child = CompositeSupport::Child.new
        leaf = CompositeSupport::Leaf.new
        leaf.child = child
        leaf.child_alt = alt_child
        expect(leaf.traversable_parents.transform_values(&:objects)).to eq({ 'Child_Id__r' => [child, alt_child] })
      end
    end

    describe '#traversable_children' do
      it 'is empty if object does not have any has_many or has_one associations' do
        object = CompositeSupport::Leaf.new
        expect(object.traversable_children).to be_empty
      end

      it 'is empty if object has has_many or has_one  associations but none are loaded' do
        object = CompositeSupport::Parent.new
        expect(object.traversable_children).to be_empty
      end

      it 'is empty if object has loaded has_many or has_one association but they are empty' do
        object = CompositeSupport::Parent.new(id: 'x')
        object.children
        object.favorite_child
        expect(object.traversable_children).to be_empty
      end

      it 'contains relationship name and value of each loaded has_many and has_one association' do
        children = [CompositeSupport::Child.new]
        friend = CompositeSupport::Friend.new
        other_children = 2.times.map { CompositeSupport::OtherChild.new }
        parent = CompositeSupport::Parent.with_children(children)
        parent.other_children = other_children
        parent.friend = friend
        expected = { 'Children__r' => children, 'OtherChildren__r' => other_children,
                     'Friends' => [friend] }
        expect(parent.traversable_children.transform_values(&:objects)).to eq(expected)
      end

      it 'combines values if associations have the same relationship name' do
        child = CompositeSupport::Child.new
        favorite_child = CompositeSupport::Child.new
        parent = CompositeSupport::Parent.with_children(child)
        parent.favorite_child = favorite_child
        expected = { 'Children__r' => [child, favorite_child] }
        expect(parent.traversable_children.transform_values(&:objects)).to eq(expected)
      end
    end
  end
end
