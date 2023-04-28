# frozen_string_literal: true

module CompositeSupport
  class Root < ActiveForce::SObject
    self.table_name = 'Root__c'

    field :text, from: 'Text'

    has_many :parents, model: 'CompositeSupport::Parent'
  end

  class Parent < ActiveForce::SObject
    self.table_name = 'Parent__c'

    field :root_id, from: 'Root_Id__c'
    field :is_something, from: 'IsSomething__c', as: :boolean

    belongs_to :root, model: Root
    has_many :children, model: 'CompositeSupport::Child'
    has_one :favorite_child, model: 'CompositeSupport::Child', foreign_key: :parent_id
  end

  class Child < ActiveForce::SObject
    self.table_name = 'Child__c'

    field :parent_id, from: 'Parent_Id__c'
    field :some_num, from: 'SomeNum__c', as: :float

    belongs_to :parent, model: Parent
    has_many :leaves, model: 'CompositeSupport::Leaf'
  end

  class Leaf < ActiveForce::SObject
    self.table_name = 'Leaf__c'

    field :child_id, from: 'Child_Id__c'

    belongs_to :child, model: Child
  end

  class SelfRelated < ActiveForce::SObject
    field :parent_id, from: 'SelfRelated_Id__c'

    belongs_to :parent, model: SelfRelated, foreign_key: :parent_id
    has_one :child, model: SelfRelated, foreign_key: :parent_id
  end
end
