# frozen_string_literal: true

require 'spec_helper'
require 'active_force/composite/tree'

module ActiveForce
  module Composite
    RSpec.describe Tree do
      let(:client) { instance_double(Restforce::Client, options: { api_version: '51.0' }) }
      let(:max_depth) { 5 }

      def tree_with_depth(depth)
        root = CompositeSupport::SelfRelated.new
        current = root
        (depth - 1).times do
          current.child = CompositeSupport::SelfRelated.new
          current = current.child
        end
        root
      end

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
          let(:root) { CompositeSupport::Parent.new.tap { |parent| parent.root = CompositeSupport::Root.new } }

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
          let(:root) { CompositeSupport::Parent.with_children(children) }
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
            let(:root) { CompositeSupport::SelfRelated.new.tap { |o| o.child = o } }

            it 'raises an ExceedsLimitError' do
              expect { subject }.to raise_error(ExceedsLimitsError, /max depth/)
            end
          end
        end
      end

      describe '#object_count' do
        it 'is 0 if root is blank' do
          expect(Tree.new(nil).object_count).to eq(0)
        end

        it 'is 1 if root has no children' do
          root = CompositeSupport::Root.new
          expect(Tree.new(root).object_count).to eq(1)
        end

        it 'counts children of root' do
          root = CompositeSupport::Parent.with_children(*3.times.map { CompositeSupport::Child.new })
          expect(Tree.new(root).object_count).to eq(4)
        end

        it 'counts children of children' do
          root = CompositeSupport::Parent.with_children(
            *3.times.map { CompositeSupport::Child.with_leaves(CompositeSupport::Leaf.new) }
          )
          expect(Tree.new(root).object_count).to eq(7)
        end

        it 'does not count already persisted objects' do
          root = CompositeSupport::Parent.with_children(CompositeSupport::Child.new(id: 'id'))
          expect(Tree.new(root).object_count).to eq(1)
        end

        it 'raises ExceedsLimitError if depth is greater than max depth' do
          expect { Tree.new(tree_with_depth(max_depth + 1)).object_count }
            .to raise_error(ExceedsLimitsError, /max depth/)
        end
      end

      describe '#update_objects' do
        let(:ids) { [] }
        let(:response) { Restforce::Mash.new(results: ids) }
        let(:uuid_generator) do
          double('uuid_generator').tap do |mock|
            sequence = ids.map { |x| x.try(:[], :referenceId) } + objects.map { SecureRandom.uuid }
            allow(mock).to receive(:uuid).and_return(*sequence)
          end
        end
        let(:root) do
          CompositeSupport::Parent.with_children(
            CompositeSupport::Child.with_leaves(CompositeSupport::Leaf.new, CompositeSupport::Leaf.new)
          ).tap do |parent|
            # So that we have a has_one association.
            parent.title = 'title'
            parent.friend = CompositeSupport::Friend.new(name: 'test')
          end
        end
        let(:objects) { ([root, root.friend] + root.children + root.children.pluck(:leaves)).flatten }
        let(:tree) { Tree.new(root, uuid_generator: uuid_generator) }

        before { tree.update_objects(response) }

        def assert_id_assigned(id_response)
          expect(tree.find_object(id_response[:referenceId]).id).to eq(id_response[:id])
        end

        def assert_marked_clean(id_response)
          expect(tree.find_object(id_response[:referenceId]).changed?).to be(false)
        end

        context 'with no ids in response' do
          it 'does not assign any ids' do
            expect(objects.pluck(:id)).to all(be_blank)
          end
        end

        context 'with nil result in response' do
          let(:ids) { [nil] }

          it 'does not assign any ids' do
            expect(objects.pluck(:id)).to all(be_blank)
          end
        end

        context 'when given error results' do
          let(:ids) { [{ referenceId: 'refId1', errors: [{ message: 'error' }] }] }

          it 'does not update ids of referenced records' do
            expect(root.id).to be_blank
          end

          it 'does not mark referenced records as unchanged' do
            expect(root.changed?).to be(true)
          end
        end

        context 'with a subset of referenced objects in response' do
          let(:ids) { [{ referenceId: 'refId1', id: 'id1' }] }

          it 'assigns ids to referenced objects' do
            ids.each { |id_response| assert_id_assigned(id_response) }
          end

          it 'marks assigned objects as unchanged' do
            ids.each { |id_response| assert_marked_clean(id_response) }
          end

          it 'updates associated parent ids of child records' do
            expect(root.friend.parent).to eq(root)
            expect(root.friend.parent_id).to eq('id1')
            expect(root.children.pluck(:parent)).to all(eq(root))
            expect(root.children.pluck(:parent_id)).to all(eq('id1'))
          end

          it 'does not update associated parents if parent id is not in response' do
            expect(root.children.pluck(:leaves).flatten.pluck(:child_id)).to all(be_nil)
          end

          it 'does not assign ids to objects not referenced in response' do
            assigned = ids.map { |id| tree.find_object(id[:referenceId]) }
            expect((objects - assigned).pluck(:id)).to all(be_blank)
          end
        end

        context 'with exactly the referenced objects in response' do
          let(:ids) do
            objects.map { { id: SecureRandom.uuid, referenceId: SecureRandom.uuid } }
          end

          it 'assigns ids to each object' do
            expect(objects.pluck(:id)).to all(be_present)
            ids.each { |id_response| assert_id_assigned(id_response) }
          end

          it 'marks assigned objects as unchanged' do
            ids.each { |id_response| assert_marked_clean(id_response) }
          end

          it 'updates associated parent ids of child records' do
            expect(root.friend.parent_id).to eq(root.id)
            expect(root.children.pluck(:parent_id)).to all(eq(root.id))
            root.children.each { |child| expect(child.leaves.pluck(:child_id)).to all(eq(child.id)) }
          end
        end

        context 'with superset of referenced objects in response' do
          let(:ids) do
            (objects + 2.times.to_a).map { { id: SecureRandom.uuid, referenceId: SecureRandom.uuid } }
          end

          it 'assigns ids to each object' do
            expect(objects.pluck(:id)).to all(be_present)
            ids.take(objects.length).each { |id_response| assert_id_assigned(id_response) }
          end

          it 'marks all objects as unchanged' do
            expect(objects.map(&:changed?)).to all(be(false))
          end

          it 'updates associated parent ids of child records' do
            expect(root.friend.parent_id).to eq(root.id)
            expect(root.children.pluck(:parent_id)).to all(eq(root.id))
            root.children.each { |child| expect(child.leaves.pluck(:child_id)).to all(eq(child.id)) }
          end
        end

        context 'with blank response' do
          let(:response) { nil }

          it 'does not assign ids to any object' do
            expect(objects.pluck(:id)).to all(be_blank)
          end
        end

        context 'when parent has children with different associations that have the same relationship name' do
          let(:root) do
            CompositeSupport::Child.new.tap do |child|
              child.friends = [CompositeSupport::Friend.new]
              child.other_children = [CompositeSupport::OtherChild.new]
            end
          end
          let(:objects) { [[root] + root.friends + root.other_children].flatten }
          let(:ids) { [{ referenceId: 'refId1', id: 'id1' }] }

          it 'updates the associated parent ids of the child records' do
            expect(root.friends.pluck(:child_id)).to all(eq(root.id))
            expect(root.other_children.pluck(:other_child_id)).to all(eq(root.id))
          end
        end

        it 'raises ExceedsLimitError if depth is greater than max depth' do
          expect { Tree.new(tree_with_depth(max_depth + 1)).update_objects({}) }
            .to raise_error(ExceedsLimitsError, /max depth/)
        end
      end
    end
  end
end
