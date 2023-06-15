# frozen_string_literal: true

require 'active_force/association/belongs_to_association'
require 'active_force/association/has_many_association'
require 'active_force/association/has_one_association'

module ActiveForce
  module Composite
    #
    # Include on SObject. Exposes methods for convenient traversing
    # that return loaded association records that may have been updated or newly built.
    #
    module Traversable
      class Relationship
        def objects
          object_association_map.keys
        end

        def add_association(association, objects)
          object_association_map.merge!((objects || []).uniq.map { |object| [object, association] }.to_h)
        end

        def assign_inverse(owner)
          object_association_map.each { |target, association| association&.assign_inverse(owner, target) }
        end

        private

        def object_association_map
          @object_association_map ||= {}
        end
      end

      def traversable_root?
        traversable_parents.blank?
      end

      def traversable_children
        loaded_relationships(Association::HasManyAssociation, Association::HasOneAssociation)
      end

      def traversable_parents
        loaded_relationships(Association::BelongsToAssociation)
      end

      private

      def loaded_relationships(*association_classes)
        loaded_associations(association_classes).each_with_object({}) do |(name, association), result|
          objects = [association_cache[name]].flatten.compact
          (result[association.relationship_name] ||= Relationship.new).add_association(association, objects)
        end
      end

      def loaded_associations(association_classes)
        self.class.associations.select do |name, assoc|
          cached = association_cache[name]
          has_loaded_value = if cached.is_a?(ActiveQuery)
                               cached.present? && cached.loaded? && cached.to_a.present?
                             else
                               cached.present?
                             end
          has_loaded_value && association_classes.any? { |klass| assoc.is_a?(klass) }
        end
      end
    end
  end
end
