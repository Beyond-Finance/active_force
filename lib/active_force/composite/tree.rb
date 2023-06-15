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

      def initialize(root, max_depth: 5, uuid_generator: SecureRandom)
        @root = root
        @max_depth = [1, max_depth || 0].max
        @uuid_generator = uuid_generator
        request
      end

      def request
        @request ||= traverse(root)
      end

      def object_count
        objects.size
      end

      def update_objects(response)
        response&.results&.each do |result|
          next if result.try(:id).blank?

          object = find_object(result.referenceId)

          next if object.blank?

          object.id = result.id
          update_relationships(object)
          # Mark that object is no longer dirty since it has been persisted.
          object.changes_applied
        end
      end

      def find_object(reference_id)
        objects[reference_id]
      end

      private

      attr_reader :uuid_generator

      def objects
        @objects ||= {}
      end

      def traverse(object, depth = 1)
        reference_id = uuid_generator.uuid
        subrequest = subrequest(reference_id, object)
        return if subrequest.blank?

        check_depth(depth)
        object.traversable_children.map do |relationship_name, relationship|
          child_subrequests = relationship.objects.map { |child| traverse(child, depth + 1) }.compact
          subrequest[relationship_name] = { records: child_subrequests }
        end
        record_object(reference_id, object)
        subrequest
      end

      def subrequest(reference_id, object)
        return if object.blank? || object.persisted?

        { attributes: { type: object.class.table_name, referenceId: reference_id } }
          .merge(object.save_request.fetch(:body, {}))
      end

      def record_object(reference_id, object)
        objects[reference_id] = object
      end

      def check_depth(depth)
        raise ExceedsLimitsError, "Tree with root #{root} exceeds max depth of #{max_depth}" if depth > max_depth
      end

      def update_relationships(object)
        object.traversable_children.each_value { |relationship| relationship.assign_inverse(object) }
      end
    end
  end
end
