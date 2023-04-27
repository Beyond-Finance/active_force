# frozen_string_literal: true

require 'active_force/composite/tree_builder'

module ActiveForce
  module Composite
    #
    # Adds methods for constructing and sending sObject Tree requests
    #
    module Treeable
      def tree(objects, **options)
        build_tree_builder(objects, **options).commit
      end

      def tree!(objects, **options)
        build_tree_builder(objects, **options).commit!
      end

      private

      def build_tree_builder(objects, **options)
        TreeBuilder.new(self, **options).tap do |b|
          b.add_roots(*objects)
        end
      end
    end
  end
end
