# frozen_string_literal: true

require 'active_force/composite/tree_sender'

module ActiveForce
  module Composite
    #
    # Adds methods for constructing and sending sObject Tree requests
    #
    module Treeable
      def tree(objects, allow_multiple_requests: false)
        tree_sender(objects, allow_multiple_requests: allow_multiple_requests).send_trees
      end

      def tree!(objects, allow_multiple_requests: false)
        tree_sender(objects, allow_multiple_requests: allow_multiple_requests).send_trees!
      end

      private

      def tree_sender(objects, **options)
        TreeSender.new(self, **options).tap do |b|
          b.add_roots(*objects)
        end
      end
    end
  end
end
