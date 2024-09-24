module ActiveForce

  module Association
    class InvalidAssociationError < StandardError; end

    class EagerLoadBuilderForNestedIncludes

      class << self
        def build(relations, current_sobject, parent_association_field = nil, query_fields = nil)
          new(relations, current_sobject, parent_association_field, query_fields).projections
        end
      end

      attr_reader :relations, :current_sobject, :association_mapping, :parent_association_field, :fields, :query_fields

      def initialize(relations, current_sobject, parent_association_field = nil, query_fields = nil)
        @relations = [relations].flatten
        @current_sobject = current_sobject
        @association_mapping = {}
        @parent_association_field = parent_association_field
        @query_fields = query_fields
        @fields = []
      end


      def projections
        relations.each do |relation|
          case relation
          when Symbol
            association = current_sobject.associations[relation]
            raise InvalidAssociationError, "Association named #{relation} was not found on #{current_sobject}" if association.nil?
            build_includes(association)
          when Hash
            build_hash_includes(relation)
          end
        end
        { fields: fields, association_mapping: association_mapping }
      end

      def build_includes(association)
        fields.concat(EagerLoadProjectionBuilder.build(association, parent_association_field, query_fields_for(association)))
        association_mapping[association.sfdc_association_field.downcase] = association.relation_name
      end

      def query_fields_for(association)
        return nil if query_fields.blank?
        query_fields_with_association = query_fields.find { |nested_field| nested_field[association.relation_name].present? }
        return nil if query_fields_with_association.blank?
        query_fields_with_association[association.relation_name].map { |field| association.relation_model.mappings[field] }
      end

      def build_hash_includes(relation, model = current_sobject, parent_association_field = nil)
        relation.each do |key, value|
          association = model.associations[key]
          raise InvalidAssociationError, "Association named #{key} was not found on #{model}" if association.nil?
          case association
          when ActiveForce::Association::BelongsToAssociation
            build_includes(association)
            nested_query = build_relation_for_belongs_to(association, value)
            fields.concat(nested_query[:fields])
            association_mapping.merge!(nested_query[:association_mapping])
          else
            nested_query = build_relation(association, value)
            fields.concat(nested_query[:fields])
            association_mapping.merge!(nested_query[:association_mapping])
          end
        end
      end

      private

      def build_relation(association, nested_includes)
        builder_class = ActiveForce::Association::EagerLoadProjectionBuilder.projection_builder_class(association)
        projection_builder = builder_class.new(association, nil, query_fields_for(association))
        sub_query = projection_builder.query_with_association_fields
        association_mapping[association.sfdc_association_field.downcase] = association.relation_name
        nested_includes_query = self.class.build(nested_includes, association.relation_model, nil, query_fields)
        sub_query.fields nested_includes_query[:fields]
        { fields: ["(#{sub_query})"], association_mapping: nested_includes_query[:association_mapping] }
      end


      def build_relation_for_belongs_to(association, nested_includes)
        if parent_association_field.present?
          current_parent_association_field = "#{parent_association_field}.#{association.sfdc_association_field}"
        else
          current_parent_association_field = association.sfdc_association_field
        end
        self.class.build(nested_includes, association.relation_model, current_parent_association_field)
      end
    end
  end
end