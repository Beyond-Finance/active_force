# frozen_string_literal: true

module ActiveForce
  module Composite
    module Treeable
      include Traversable

      def self.tree(objects, **options)
        t = TreeBuilder.new(self, **options)
        objects.each { |object| t.add_root(object) }
        t.commit
      end
    end
  end
end
