# frozen_string_literal: true

require 'active_force/composite/errors'
require 'securerandom'

module ActiveForce
  module Composite
    #
    # Represents a single rooted sObject tree.
    #
    class Tree
      attr_reader :root, :max_depth

      def self.build(root, **kwargs)
        tree = new(root, **kwargs)
        tree.request
      end

      def initialize(root, max_depth: 5)
        @root = root
        @max_depth = max_depth
      end

      def request
        @request ||= traverse(root)
      end

      def object_count
        objects.size
      end

      def assign_ids(response)
        response&.results&.each { |result| objects[result.referenceId]&.id = result.id }
      end

      private

      def objects
        @objects ||= {}
      end

      def traverse(object, depth = 1)
        reference_id = SecureRandom.uuid
        subrequest = subrequest(reference_id, object)
        return if subrequest.blank?

        check_depth(depth)
        object.traversable_children.each do |relationship_name, children|
          subrequest[relationship_name] = { records: children.map { |child| traverse(child, depth + 1) }.compact }
        end
        record_object(reference_id, object)
        subrequest
      end

      def subrequest(reference_id, object)
        return if object.blank? || object.persisted?

        { attributes: { type: object.class.table_name, referenceId: reference_id } }
          .merge(object.save_request[:body] || {})
      end

      def record_object(reference_id, object)
        object[reference_id] = object
      end

      def check_depth(depth)
        raise ExceedsLimitsError, "Tree with root #{root} exceeds max depth of #{max_depth}" if depth > max_depth
      end
    end
  end
end
