# frozen_string_literal: true

module CompositeSupport
  class Root < ActiveForce::SObject
    self.table_name = 'Root__c'

    field :title, from: 'Title'
    field :body, from: 'Body__c'
    field :other_field, from: 'OtherField', as: :float

    has_many :parents, model: 'CompositeSupport::Parent'
  end

  class Parent < ActiveForce::SObject
    self.table_name = 'Parent__c'

    field :root_id, from: 'Root_Id__c'
    field :is_something, from: 'IsSomething__c', as: :boolean
    field :title, from: 'Title'

    belongs_to :root, model: Root
    has_many :children, model: 'CompositeSupport::Child'
    has_many :other_children, model: 'CompositeSupport::OtherChild'
    has_one :favorite_child, model: 'CompositeSupport::Child',
                             foreign_key: :parent_id, scoped_as: -> { where(is_favorite: true) }

    def self.with_children(*children)
      new.tap { |r| r.children = children }
    end
  end

  class Child < ActiveForce::SObject
    self.table_name = 'Child__c'

    field :parent_id, from: 'Parent_Id__c'
    field :name, from: 'Name'
    field :some_num, from: 'SomeNum__c', as: :float
    field :another_field, from: 'AnotherField'
    field :is_favorite, from: 'IsFavorite__c', as: :boolean

    belongs_to :parent, model: Parent
    has_many :leaves, model: 'CompositeSupport::Leaf', relationship_name: 'Leaves__r'

    def self.with_leaves(*leaves)
      new.tap { |c| c.leaves = leaves }
    end
  end

  class OtherChild < ActiveForce::SObject
    self.table_name = 'OtherChild__c'

    field :parent_id, from: 'Parent_Id__c'
    field :name, from: 'Name'

    belongs_to :parent, model: Parent
  end

  class Leaf < ActiveForce::SObject
    self.table_name = 'Leaf__c'

    field :child_id, from: 'Child_Id__c'
    field :name, from: 'Name'

    belongs_to :child, model: Child
  end

  class SelfRelated < ActiveForce::SObject
    field :parent_id, from: 'SelfRelated_Id__c'

    belongs_to :parent, model: SelfRelated, foreign_key: :parent_id
    has_one :child, model: SelfRelated, foreign_key: :parent_id
  end
end
