module ActiveForce
  module Association
    class HasOneAssociation < Association
      private

      def target(owner)
        relation_model.find_by(foreign_key => owner.id)
      end

      def default_foreign_key
        infer_foreign_key_from_model parent
      end

      def define_assignment_method
        association = self
        method_name = relation_name
        parent.send :define_method, "#{method_name}=" do |other|
          other = other.first if other.is_a?(Array)
          if persisted?
            value_to_set = other.nil? ? nil : id
            # Do we change the object that was passed in or do we modify the already associated object?
            obj_to_change = value_to_set ? other : send(method_name)
            obj_to_change.send "#{association.foreign_key}=", value_to_set
          end
          association_cache[method_name] = other
        end
      end
    end
  end
end
