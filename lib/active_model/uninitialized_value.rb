require 'active_model'

module ActiveModel
  class Attribute
    class UninitializedValue < Uninitialized # :nodoc:

      def value
        raise ActiveModel::MissingAttributeError, "missing attribute: #{name}"
      end
    end
  end
end
