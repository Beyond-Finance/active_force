# frozen_string_literal: true

require 'active_force/association/belongs_to_association'
require 'active_force/association/has_many_association'
require 'active_force/association/has_one_association'
require 'set'

module ActiveForce
  module Composite
    #
    # Include on SObject. Exposes methods for convenient traversing
    # that return loaded association records that may have been updated or newly built.
    #
    module Traversable
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
          (result[association.relationship_name] ||= Set.new).merge(objects)
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
