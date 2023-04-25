# frozen_string_literal: true

module ActiveForce
  module Composite
    class TreeBuilder
      def initialize(root_object_class, **options)
        @root_object_class = root_object_class
        @options = options
        @committed = false
      end

      def commit
        raise InvalidOperationError, 'trees have already been committed' if committed?

        send_tree_requests(roots.map { |root| Tree.build(root) })
        @committed = true
      end

      def committed?
        @committed
      end

      def add_root(object)
        raise ArgumentError, "All root objects must be #{root_object_class}" unless object.is_a?(root_object_class)
        raise ExceedsLimitsError, "Cannot have more than #{max_objects} objects in one request" if max_roots?

        roots << object
      end

      private

      attr_reader :root_object_class, :options

      def send_tree_requests(trees)
        errors = []
        batch_trees(trees).each do |batch|
          response = send_request({ records: combine_tree_requests(batch) })
          batch.each { |tree| tree.assign_ids(response) }
        rescue FailedRequestError => e
          errors << e
        end
        # TODO
        raise FailedRequestError.new(errors) if errors.present?
      end

      def combine_tree_requests(trees)
        trees.map(&:request).compact_blank
      end

      def batch_trees(trees)
        trees.each_with_object([]) do |tree, batches|
          current_batch = batches.last
          if current_batch.blank? || tree_overflows_batch?(current_batch, tree)
            current_batch = []
            batches << current_batch
          end
          current_batch << tree
        end
      end

      def tree_overflows_batch?(batch, new_tree)
        overflows = (batch + [new_tree]).sum(&:objects_count) > max_objects
        if overflows && !allow_multiple_requests?
          raise ExceedsLimitsError, "Cannot have more than #{max_objects} in one request"
        end

        overflows
      end

      def send_request(body)
        response = ActiveForce.sfdc_client.api_post("composite/tree/#{object_name}", body.to_json)
        raise_on_error(response)
        response
      end

      def raise_on_error(response)
        # TODO
      end

      def max_roots?
        !allow_multiple_requests? && roots.size >= max_objects
      end

      def allow_multiple_requests?
        !!options[:allow_multiple_requests]
      end

      def roots
        @roots ||= Set.new
      end

      def max_objects
        @max_objects ||= (options[:max_objects] || 200)
      end
    end
  end
end
