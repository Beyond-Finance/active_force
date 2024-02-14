module ActiveForce
  module Association
    class RelationModelBuilder
      class << self
        def build(association, value, association_mapping = {})
          new(association, value, association_mapping).build_relation_model
        end
      end

      def initialize(association, value, association_mapping = {})
        @association = association
        @value = value
        @association_mapping = association_mapping
      end

      def build_relation_model
        klass = resolve_class
        klass.new(@association, @value, @association_mapping).call
      end

      private

      def resolve_class
        association_builder = @value.class.name.gsub('::', '_')
        ActiveForce::Association.const_get "BuildFrom#{association_builder}"
      rescue NameError
        raise "Don't know how to build relation from #{@value.class.name}"
      end
    end

    class AbstractBuildFrom
      attr_reader :association, :value, :association_mapping

      def initialize(association, value, association_mapping = {})
        @association = association
        @value = value
        @association_mapping = association_mapping
      end

      def call
        raise "Must implement #{self.class.name}#call"
      end
    end

    class BuildFromHash < AbstractBuildFrom
      def call
        association.build(value, association_mapping)
      end
    end

    class BuildFromArray < AbstractBuildFrom
      def call
        if association.is_a?(HasOneAssociation)
          association.build(value.first, association_mapping)
        else
          value.map { |mash| association.build(mash, association_mapping) }
        end
      end
    end

    class BuildFromNilClass < AbstractBuildFrom
      def call
        association.is_a?(HasManyAssociation) ? [] : nil
      end
    end

    class BuildFromRestforce_SObject < BuildFromHash
    end

    class BuildFromRestforce_Mash < BuildFromHash
    end

    class BuildFromRestforce_Collection < BuildFromArray
    end
  end
end
