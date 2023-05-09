# frozen_string_literal: true

require 'active_force/composite/tree_builder'

module ActiveForce
  module Composite
    #
    # Adds methods for constructing and sending sObject Tree requests
    #
    module Treeable
      def tree(objects, allow_multiple_requests: false)
        tree_builder(objects, allow_multiple_requests: allow_multiple_requests).commit
      end

      def tree!(objects, allow_multiple_requests: false)
        tree_builder(objects, allow_multiple_requests: allow_multiple_requests).commit!
      end

      private

      def tree_builder(objects, **options)
        TreeBuilder.new(self, **options).tap do |b|
          b.add_roots(*objects)
        end
      end
    end
  end
end
