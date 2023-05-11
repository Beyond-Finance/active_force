# frozen_string_literal: true

require 'active_force'
require 'active_force/composite/errors'
require 'active_force/composite/tree'
require 'set'

module ActiveForce
  module Composite
    #
    # Entrypoint for constructing and sending sObject Tree requests, all with the same root object type.
    # This can send multiple trees in a single request
    # and also provides an option (allow_multiple_requests) for sending multiple requests
    # that will stay within total object limits enforced by the Salesforce REST API.
    # allow_multiple_requests is false by default, since typically you would want these
    # requests to all succeed or fail together.
    #
    class TreeSender
      def initialize(root_object_class, allow_multiple_requests: false, max_objects: 200)
        @root_object_class = root_object_class
        @allow_multiple_requests = allow_multiple_requests
        @max_objects = max_objects
      end

      def send_trees
        send_tree_requests(roots.map { |root| Tree.new(root) })
      end

      def send_trees!
        send_trees.tap do |result|
          raise FailedRequestError, result.error_responses unless result.success?
        end
      end

      def add_roots(*objects)
        objects&.each { |object| add_root(object) }
      end

      private

      attr_reader :root_object_class, :max_objects

      def add_root(object)
        raise ArgumentError, "All root objects must be #{root_object_class}" unless object.is_a?(root_object_class)
        raise ExceedsLimitsError, "Cannot have more than #{max_objects} objects in one request" if max_roots?

        roots << object
      end

      def send_tree_requests(trees)
        error_responses = []
        batch_trees(trees).each do |batch|
          response = send_request({ records: combine_tree_requests(batch) })
          batch.each { |tree| tree.assign_ids(response) }
          error_responses << response if response&.hasErrors
        end
        Result.new(error_responses)
      end

      def combine_tree_requests(trees)
        trees.map(&:request).compact_blank
      end

      def batch_trees(trees)
        trees.each_with_object([]) do |tree, batches|
          check_size(tree)
          current_batch = batches.last
          if current_batch.blank? || tree_overflows_batch?(current_batch, tree)
            current_batch = []
            batches << current_batch
          end
          current_batch << tree
        end
      end

      def tree_overflows_batch?(batch, new_tree)
        overflows = (batch + [new_tree]).sum(&:object_count) > max_objects
        if overflows && !allow_multiple_requests?
          raise ExceedsLimitsError, "Cannot have more than #{max_objects} in one request"
        end

        overflows
      end

      def check_size(tree)
        raise ExceedsLimitsError, "A tree has more than #{max_objects} objects" if tree.object_count > max_objects
      end

      def send_request(body)
        ActiveForce.sfdc_client.api_post("composite/tree/#{root_object_class.table_name}", body.to_json)&.body
      rescue Restforce::ResponseError => e
        Restforce::Mash.new(e.response&.fetch(:body, nil) || default_restforce_error(e))
      end

      def max_roots?
        !allow_multiple_requests? && roots.size >= max_objects
      end

      def allow_multiple_requests?
        !!@allow_multiple_requests
      end

      def roots
        @roots ||= Set.new
      end

      def default_restforce_error(exception)
        { hasErrors: true,
          results: [{
            errors: [{ message: "Restforce::ResponseError without body: #{exception}" }]
          }] }
      end

      Result = Struct.new(:error_responses) do
        def success?
          error_responses.blank?
        end
      end
    end
  end
end
