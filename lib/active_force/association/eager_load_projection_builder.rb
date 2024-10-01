module ActiveForce
  module Association
    class InvalidEagerLoadAssociation < StandardError; end
    class EagerLoadProjectionBuilder
      class << self
        def build(association, parent_association_field = nil, query_fields = nil)
          new(association, parent_association_field, query_fields).projections
        end

        def projection_builder_class(association)
          klass = association.class.name.demodulize
          ActiveForce::Association.const_get "#{klass}ProjectionBuilder"
        rescue NameError
          raise "No projection builder exists for #{klass}"
        end
      end

      attr_reader :association, :parent_association_field, :query_fields

      def initialize(association, parent_association_field = nil, query_fields = nil)
        @association = association
        @parent_association_field = parent_association_field
        @query_fields = query_fields
      end

      def projections
        builder_class = self.class.projection_builder_class(association)
        builder_class.new(association, parent_association_field, query_fields).projections
      end
    end

    class AbstractProjectionBuilder
      attr_reader :association, :parent_association_field, :query_fields

      def initialize(association, parent_association_field = nil, query_fields = nil)
        @association = association
        @parent_association_field = parent_association_field
        @query_fields = query_fields
      end

      def projections
        raise "Must define #{self.class.name}#projections"
      end

      def apply_association_scope(query)
        return query unless association.scoped?
        raise InvalidEagerLoadAssociation, "Cannot use scopes that expect arguments: #{association.relation_name}" if association.scoped_as.arity.positive?

        query.instance_exec(&association.scoped_as)
      end

      ###
      # Use ActiveForce::Query to build a subquery for the SFDC
      # relationship name. Per SFDC convention, the name needs
      # to be pluralized
      def query_with_association_fields
        relationship_name = association.sfdc_association_field
        selected_fields = query_fields || association.relation_model.fields
        query = ActiveQuery.new(association.relation_model, relationship_name).select(*selected_fields)
        apply_association_scope(query)
      end
    end

    class HasManyAssociationProjectionBuilder < AbstractProjectionBuilder
      def projections
        ["(#{query_with_association_fields.to_s})"]
      end
    end

    class HasOneAssociationProjectionBuilder < AbstractProjectionBuilder
      def projections
        ["(#{query_with_association_fields.to_s})"]
      end
    end

    class BelongsToAssociationProjectionBuilder < AbstractProjectionBuilder
      def projections
        association_field = if parent_association_field.present?
                              "#{ parent_association_field }.#{ association.sfdc_association_field }"
                            else
                              association.sfdc_association_field
                            end
        selected_fields = query_fields || association.relation_model.fields
        selected_fields.map do |field|
          "#{ association_field }.#{ field }"
        end
      end
    end
  end
end
