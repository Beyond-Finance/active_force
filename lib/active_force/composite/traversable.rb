# frozen_string_literal: true

module ActiveForce
  module Composite
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
        associations
          .select { |name, assoc| association_cache.key?(name) && association_classes.any? { |klass| assoc.is_a?(klass)} }
          .each_with_object({}) do |name, association, result|
            objects = [association_cache[name]].flatten.compact
            (result[association.relationship_name] ||= Set.new).merge(objects)
          end
      end
    end
  end
end
