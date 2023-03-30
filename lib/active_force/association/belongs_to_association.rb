module ActiveForce
  module Association
    class BelongsToAssociation < Association
      def relationship_name
        options[:relationship_name] || default_relationship_name
      end

      private

      def loadable?(owner)
        foreign_key_value(owner).present?
      end

      def target(owner)
        relation_model.find(foreign_key_value(owner))
      end

      def default_relationship_name
        parent.mappings[foreign_key].gsub(/__c\z/, '__r')
      end

      def default_foreign_key
        infer_foreign_key_from_model relation_model
      end

      def foreign_key_value(owner)
        owner&.public_send(foreign_key)
      end

      def define_assignment_method
        association = self
        method_name = relation_name
        parent.send :define_method, "#{method_name}=" do |other|
          send "#{association.foreign_key}=", other&.id
          association_cache[method_name] = other
        end
      end
    end
  end
end
