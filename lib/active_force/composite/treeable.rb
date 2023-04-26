# frozen_string_literal: true

module ActiveForce
  module Composite
    module Treeable
      include Traversable

      class << self
        def self.tree(objects, **options)
          build_tree_builder(objects, **options).commit
        end

        def self.tree!(objects, **options)
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
end
