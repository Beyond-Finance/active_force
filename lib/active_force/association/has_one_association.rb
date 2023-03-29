module ActiveForce
  module Association
    class HasOneAssociation < Association
      private

      def default_foreign_key
        infer_foreign_key_from_model @parent
      end

      def define_relation_method
        association = self
        _method = @relation_name
        @parent.send :define_method, _method do
          association_cache.fetch(_method) do
            association_cache[_method] = id.present? ? association.relation_model.find_by(association.foreign_key => id) : nil
          end
        end

        @parent.send :define_method, "#{_method}=" do |other|
          value_to_set = other.nil? ? nil : self.id
          other = other.first if other.is_a?(Array)
          # Do we change the object that was passed in or do we modify the already associated object?
          obj_to_change = value_to_set ? other : self.send(association.relation_name)
          obj_to_change.send "#{ association.foreign_key }=", value_to_set
          association_cache[_method] = other
        end
      end
    end
  end
end
