# frozen_string_literal: true

require 'spec_helper'
require 'active_force/composite/tree'

module ActiveForce
  module Composite
    RSpec.describe Tree do
      let(:client) { instance_double(Restforce::Client, options: { api_version: '51.0' }) }

      before do
        ActiveForce.sfdc_client = client
      end

      describe '#initialize' do
        let(:root) { CompositeSupport::Root.new }

        it 'assigns root' do
          expect(Tree.new(root).root).to eq(root)
        end

        it 'assigns default max_depth of 5' do
          expect(Tree.new(root).max_depth).to eq(5)
        end

        it 'assigns max_depth if given' do
          expect(Tree.new(root, max_depth: 3).max_depth).to eq(3)
        end

        it 'clamps minimum max_depth at 1' do
          expect(Tree.new(root, max_depth: -1).max_depth).to eq(1)
        end
      end

      describe '#request' do
        let(:max_depth) { 5 }
        let(:root) { CompositeSupport::Root.new }
        let(:tree) { Tree.new(root, max_depth: max_depth) }

        subject { tree.request }

        def reference_ids(request = subject, reference_ids = [])
          request.values.map { |v| v.respond_to?(:fetch) && v.fetch(:records, nil) }.compact_blank.flatten
                 .each { |record| reference_ids(record, reference_ids) }
          reference_ids << request.dig(:attributes, :referenceId)
        end

        def assert_unique_reference_ids
          ids = reference_ids
          expect(ids).to match_array(ids.uniq)
        end

        context 'when root object is blank' do
          let(:root) { nil }

          it { is_expected.to be_nil }
        end

        context 'when root object is already persisted' do
          before { root.id = 'some_id' }

          it { is_expected.to be_nil }
        end

        context 'when root object has no associations' do
          it 'has :attributes with the correct type' do
            expect(subject.dig(:attributes, :type)).to eq(root.table_name)
          end

          it 'has :attributes with a reference id' do
            expect(subject.dig(:attributes, :referenceId)).to be_present
          end

          it 'includes all and only updated model attributes' do
            root.title = 'test_title'
            root.body = 'test_body'
            expect(subject.keys).to match_array([:attributes, 'Title', 'Body__c'])
            expect(subject['Title']).to eq('test_title')
            expect(subject['Body__c']).to eq('test_body')
          end
        end

        context 'when root object has only parent associations' do
          let(:root) do
            parent = CompositeSupport::Parent.new
            parent.root = CompositeSupport::Root.new
            parent
          end

          it 'has :attributes with the correct type' do
            expect(subject.dig(:attributes, :type)).to eq(root.table_name)
          end

          it 'has :attributes with a reference id' do
            expect(subject.fetch(:attributes, :referenceId)).to be_present
          end

          it 'includes all and only updated model attributes and no associations' do
            root.is_something = true
            expect(subject.keys).to match_array([:attributes, 'IsSomething__c'])
            expect(subject['IsSomething__c']).to be(true)
          end
        end

        context 'when root object has child associations' do
          let(:children) { 2.times.map { CompositeSupport::Child.new } }
          let(:root) do
            parent = CompositeSupport::Parent.new
            parent.children = children
            parent
          end
          let(:child_subrequests) do
            relationship_name = root.class.associations[:children].relationship_name
            subject.dig(relationship_name, :records)
          end

          it 'includes attributes and updated fields of the root' do
            root.title = 'test_title'
            expect(subject.dig(:attributes, :type)).to eq(root.table_name)
            expect(subject.dig(:attributes, :referenceId)).to be_present
            expect(subject['Title']).to eq('test_title')
          end

          it 'includes subrequests for children' do
            expect(child_subrequests.length).to eq(children.length)
            child_subrequests.each do |subrequest|
              expect(subrequest.dig(:attributes, :type)).to eq(CompositeSupport::Child.table_name)
              expect(subrequest.dig(:attributes, :referenceId)).to be_present
            end
          end

          it 'includes updated fields of children' do
            children.first.some_num = 42
            children.last.another_field = 'test_value'

            expect(child_subrequests.first['SomeNum__c']).to eq(42)
            expect(child_subrequests.first.keys).to match_array([:attributes, 'SomeNum__c'])

            expect(child_subrequests.last['AnotherField']).to eq('test_value')
            expect(child_subrequests.last.keys).to match_array([:attributes, 'AnotherField'])
          end

          it 'has unique reference ids for each subrequest' do
            assert_unique_reference_ids
          end

          context 'with their own child associations' do
            let(:first_leaf) { CompositeSupport::Leaf.new(name: 'first') }
            let(:last_leaf) { CompositeSupport::Leaf.new(name: 'last') }
            let(:leaves_relationship_name) { CompositeSupport::Child.associations[:leaves].relationship_name }

            before do
              children.first.leaves = [first_leaf]
              children.last.leaves = [last_leaf]
            end

            it 'includes subrequests for the level N children' do
              expect(child_subrequests.length).to eq(children.length)
              expect(child_subrequests.map { |s| s.dig(:attributes, :type) })
                .to all(eq(CompositeSupport::Child.table_name))
            end

            it 'includes subrequests for the level N+1 children' do
              child_subrequests.each do |subrequest|
                leaf_subrequests = subrequest.dig(leaves_relationship_name, :records)
                expect(leaf_subrequests.length).to eq(1)
                expect(leaf_subrequests.first.dig(:attributes, :type)).to eq(CompositeSupport::Leaf.table_name)
                expect(leaf_subrequests.first.dig(:attributes, :referenceId)).to be_present
              end
            end

            it 'includes updated attributes for level N+1 children' do
              first_leaf_subrequest = child_subrequests.first.dig(leaves_relationship_name, :records).first
              last_leaf_subrequest = child_subrequests.last.dig(leaves_relationship_name, :records).first
              expect(first_leaf_subrequest['Name']).to eq(first_leaf.name)
              expect(last_leaf_subrequest['Name']).to eq(last_leaf.name)
            end

            it 'has unique reference ids for each subrequest' do
              assert_unique_reference_ids
            end
          end

          context 'with some that are already persisted' do
            before do
              child = children.first
              child.id = 'test_id'
              child.name = 'persisted'
            end

            it 'does not include subrequests for persisted records' do
              expect(child_subrequests.length).to eq(children.length - 1)
              expect(child_subrequests.none? { |s| s['Name'] == 'persisted' }).to be(true)
            end
          end

          context 'with the same object but on different, scoped association with same relationship' do
            let(:favorite_child) { CompositeSupport::Child.new(is_favorite: true) }

            before do
              root.favorite_child = favorite_child
            end

            it 'includes all subrequests under the same relationship' do
              expect(child_subrequests.length).to eq(children.length + 1)
              expect(child_subrequests.map { |s| s.dig(:attributes, :type) })
                .to all(eq(CompositeSupport::Child.table_name))
            end

            it 'includes updated fields' do
              expect(child_subrequests.select { |s| s['IsFavorite__c'] }.length).to eq(1)
            end
          end

          context 'with different objects' do
            let(:other_children) { 2.times.map { CompositeSupport::OtherChild.new } }
            let(:other_child_subrequests) do
              relationship_name = root.class.associations[:other_children].relationship_name
              subject.dig(relationship_name, :records)
            end

            before do
              root.other_children = other_children
            end

            it 'includes subrequests for each object type' do
              expect(child_subrequests.length).to eq(children.length)
              expect(other_child_subrequests.length).to eq(children.length)
            end

            it 'uses the correct object type in subrequest attributes' do
              expect(child_subrequests.map { |s| s.dig(:attributes, :type) })
                .to all(eq(CompositeSupport::Child.table_name))
              expect(other_child_subrequests.map { |s| s.dig(:attributes, :type) })
                .to all(eq(CompositeSupport::OtherChild.table_name))
            end

            it 'has unique reference ids for each subrequest' do
              assert_unique_reference_ids
            end
          end

          def tree_with_depth(depth)
            root = CompositeSupport::SelfRelated.new
            current = root
            (depth - 1).times do
              current.child = CompositeSupport::SelfRelated.new
              current = current.child
            end
            root
          end

          context 'with depth equal to max_depth' do
            let(:root) { tree_with_depth(max_depth) }
            let(:relationship_name) { CompositeSupport::SelfRelated.associations[:child].relationship_name }

            it 'has unique reference ids for all subrequests' do
              assert_unique_reference_ids
            end

            it 'includes request for each level' do
              current = subject
              count = 0
              while current.present?
                expect(current.dig(:attributes, :type)).to eq(CompositeSupport::SelfRelated.table_name)
                current = current.dig(relationship_name, :records)&.first
                count += 1
              end
              expect(count).to eq(max_depth)
            end
          end

          context 'with depth greater than max_depth' do
            let(:root) { tree_with_depth(max_depth + 1) }

            it 'raises ExceedsLimitError' do
              expect { subject }.to raise_error(ExceedsLimitsError, /max depth/)
            end
          end

          context 'with cyclical self-reference' do
            let(:root) do
              object = CompositeSupport::SelfRelated.new
              object.child = object
              object
            end

            it 'raises an ExceedsLimitError' do
              expect { subject }.to raise_error(ExceedsLimitsError, /max depth/)
            end
          end
        end
      end
      describe '#object_count'
      describe '#assign_ids'
      describe '.build'
    end
  end
end
