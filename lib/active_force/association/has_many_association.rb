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

      def default_foreign_key
        infer_foreign_key_from_model @parent
      end

      def target(owner)
        apply_scope(relation_model.query, owner).where(foreign_key => owner.id)
      end

      def untargetable_value
        relation_model.none
      end

      def apply_scope(query, owner)
        return query unless (scope = options[:scoped_as])

        if scope.arity.positive?
          query.instance_exec(owner, &scope)
        else
          query.instance_exec(&scope)
        end
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
