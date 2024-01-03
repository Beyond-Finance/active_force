require 'active_model'

module ActiveModel
  class Attribute
    class UninitializedSobject < Uninitialized # :nodoc:

      def value
        raise ActiveModel::MissingAttributeError, "missing attribute: #{name}"
      end
    end
  end
end
