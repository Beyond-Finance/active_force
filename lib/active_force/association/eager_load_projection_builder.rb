module ActiveForce
  module Association
    class InvalidEagerLoadAssociation < StandardError; end
    class EagerLoadProjectionBuilder
      class << self
        def build(association, parent_association_field = nil)
          new(association, parent_association_field).projections
        end
      end

      attr_reader :association, :parent_association_field

      def initialize(association, parent_association_field = nil)
        @association = association
        @parent_association_field = parent_association_field
      end

      def projections
        klass = association.class.name.split('::').last
        builder_class = ActiveForce::Association.const_get "#{klass}ProjectionBuilder"
        builder_class.new(association, parent_association_field).projections
      rescue NameError
        raise "Don't know how to build projections for #{klass}"
      end
    end

    class AbstractProjectionBuilder
      attr_reader :association, :parent_association_field

      def initialize(association, parent_association_field = nil)
        @association = association
        @parent_association_field = parent_association_field
      end

      def projections
        raise "Must define #{self.class.name}#projections"
      end

      def apply_association_scope(query)
        return query unless association.scoped?
        raise InvalidEagerLoadAssociation, "Cannot use scopes that expect arguments: #{association.relation_name}" if association.scoped_as.arity.positive?

        query.instance_exec(&association.scoped_as)
      end
    end

    class HasManyAssociationProjectionBuilder < AbstractProjectionBuilder
      ###
      # Use ActiveForce::Query to build a subquery for the SFDC
      # relationship name. Per SFDC convention, the name needs
      # to be pluralized
      def projections
        relationship_name = association.sfdc_association_field
        query = ActiveQuery.new(association.relation_model, relationship_name)
        query.fields association.relation_model.fields
        ["(#{apply_association_scope(query).to_s})"]
      end
    end

    class HasOneAssociationProjectionBuilder < AbstractProjectionBuilder
      def projections
        query = ActiveQuery.new(association.relation_model, association.sfdc_association_field)
        query.fields association.relation_model.fields
        ["(#{apply_association_scope(query).to_s})"]
      end
    end

    class BelongsToAssociationProjectionBuilder < AbstractProjectionBuilder
      def projections
        association_field = if parent_association_field.present?
                              "#{ parent_association_field }.#{ association.sfdc_association_field }"
                            else
                              association.sfdc_association_field
                            end
        association.relation_model.fields.map do |field|
          "#{ association_field }.#{ field }"
        end
      end
    end
  end
end
