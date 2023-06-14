module ActiveForce
  module Association
    class HasOneAssociation < Association
      private

      def invertible?
        true
      end

      def target(owner)
        apply_scope(relation_model.query, owner).find_by(foreign_key => owner.id)
      end

      def default_foreign_key
        infer_foreign_key_from_model parent
      end

      def define_assignment_method
        foreign_key = self.foreign_key
        method_name = relation_name
        parent.send :define_method, "#{method_name}=" do |new_target|
          new_target = new_target.first if new_target.is_a?(Array)
          if new_target.present?
            new_target.public_send("#{foreign_key}=", id)
          else
            current_target = public_send(method_name)
            current_target&.public_send("#{foreign_key}=", nil)
          end
          association_cache[method_name] = new_target
        end
      end
    end
  end
end
