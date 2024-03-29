require 'spec_helper'

module ActiveForce
  module Association
    describe RelationModelBuilder do
      let(:instance){ described_class.new association, value }

      describe '#build_relation_model' do
        context 'has_many' do
          let(:association){ HasManyAssociation.new Post, :comments }

          context 'with values' do
            let(:value) do
              build_restforce_collection([
                Restforce::SObject.new({'Id' => '213', 'PostId' => '123'}),
                Restforce::SObject.new({'Id' => '214', 'PostId' => '123'})
              ])
            end

            it 'returns an array of Comments' do
              comments = instance.build_relation_model
              expect(comments).to be_a Array
              expect(comments.all?{ |c| c.is_a? Comment }).to be true
            end
          end

          context 'without values' do
            let(:value){ nil }

            it 'returns an empty array' do
              comments = instance.build_relation_model
              expect(comments).to be_a Array
              expect(comments).to be_empty
            end
          end
        end

        context 'belongs_to' do
          let(:association){ BelongsToAssociation.new(Comment, :post) }

          context 'with a value' do
            let(:value) do
              build_restforce_sobject 'Id' => '213'
            end

            it 'returns a post' do
              expect(instance.build_relation_model).to be_a Post
            end
          end

          context 'without a value' do
            let(:value){ nil }

            it 'returns nil' do
              expect(instance.build_relation_model).to be_nil
            end
          end
        end

        context 'has_one' do
          let(:association){ HasOneAssociation.new(HasOneParent, :has_one_child) }

          context 'with a value' do
            let(:value) do
              build_restforce_sobject 'Id' => '213'
            end

            it 'returns a child' do
              expect(instance.build_relation_model).to be_a HasOneChild
            end
          end

          context 'with a restforce collection value' do
            let(:value) do
              build_restforce_collection([
                                           build_restforce_sobject('Id' => 'first'),
                                           build_restforce_sobject('Id' => 'second')
                                         ])
            end

            it 'returns a child for the first value' do
              actual = instance.build_relation_model
              expect(actual).to be_a(HasOneChild)
              expect(actual.id).to eq('first')
            end
          end

          context 'with an array value' do
            let(:value) do
              [
                build_restforce_sobject('Id' => 'first'),
                build_restforce_sobject('Id' => 'second')
              ]
            end

            it 'returns a child for the first value' do
              actual = instance.build_relation_model
              expect(actual).to be_a(HasOneChild)
              expect(actual.id).to eq('first')
            end
          end

          context 'without a value' do
            let(:value){ nil }

            it 'returns nil' do
              expect(instance.build_relation_model).to be_nil
            end
          end
        end
      end
    end
  end
end
