module ActiveForce
  module Association
    class BelongsToAssociation < Association

      def relationship_name
        options[:relationship_name] || default_relationship_name
      end

      private

      def default_relationship_name
        @parent.mappings[foreign_key].gsub /__c\z/, '__r'
      end

      def default_foreign_key
        infer_foreign_key_from_model relation_model
      end

      def define_relation_method
        association = self
        _method = @relation_name
        @parent.send :define_method, _method do
          association_cache.fetch(_method) do
            association_cache[_method] = association.relation_model.find(send association.foreign_key)
          end
        end

        @parent.send :define_method, "#{_method}=" do |other|
          send "#{ association.foreign_key }=", other.nil? ? nil : other.id
          association_cache[_method] = other
        end
      end
    end
  end
end
