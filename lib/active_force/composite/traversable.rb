# frozen_string_literal: true

module ActiveForce
  module Composite
    module Traversable
      def traversable_root?
        traversable_parents.blank?
      end

      def traversable_children
        loaded_associations_by_object_name(Association::HasManyAssociation, Association::HasOneAssociation)
      end

      def traversable_parents
        loaded_associations_by_object_name(Association::BelongsToAssociation)
      end

      private

      def loaded_associations_by_object_name(*association_classes)
        associations
          .select { |name, assoc| association_cache.key?(name) && association_classes.include?(assoc.class) }
          .each_with_object({}) do |name, association, result|
            # relationship_name seems wrong?
            result[association.relationship_name] = Set.new unless result.key?(association.relationship_name)
            result[association.relationship_name].merge([association_cache[name]].flatten)
          end
      end
    end
  end
end
