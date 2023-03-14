module ActiveForce
  module Association
    class HasManyAssociation < Association
      def sfdc_association_field
        name = relationship_name.gsub /__c\z/, '__r'
        match = name.match /__r\z/
        # pluralize the table name, and append '__r' if it was there to begin with
        name.sub(match.to_s, '').pluralize + match.to_s
      end

      private

      def default_foreign_key
        infer_foreign_key_from_model @parent
      end

      def define_relation_method
        association = self
        _method = @relation_name
        @parent.send :define_method, _method do
          association_cache.fetch _method do
            query = association.relation_model.query
            if scope = association.options[:scoped_as]
              if scope.arity > 0
                query.instance_exec self, &scope
              else
                query.instance_exec &scope
              end
            end
            association_cache[_method] = query.where association.foreign_key => self.id
          end
        end

        @parent.send :define_method, "#{_method}=" do |associated|
          association_cache[_method] = associated
        end
      end
    end
  end
end
