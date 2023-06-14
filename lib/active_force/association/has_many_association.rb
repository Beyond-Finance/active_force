module ActiveForce
  module Association
    class HasManyAssociation < Association
      def sfdc_association_field
        name = relationship_name.gsub(/__c\z/, '__r')
        match = name.match(/__r\z/)
        # pluralize the table name, and append '__r' if it was there to begin with
        name.sub(match.to_s, '').pluralize + match.to_s
      end

      private

      def invertible?
        true
      end

      def default_foreign_key
        infer_foreign_key_from_model parent
      end

      def target(owner)
        apply_scope(relation_model.query, owner).where(foreign_key => owner.id)
      end

      def target_when_unloadable
        relation_model.none
      end

      def define_assignment_method
        method_name = relation_name
        parent.send :define_method, "#{method_name}=" do |associated|
          association_cache[method_name] = associated
        end
      end
    end
  end
end
