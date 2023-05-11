require 'active_model'

module ActiveModel
  module Type
    module Salesforce
      class Multipicklist < ActiveModel::Type::Value
        include ActiveModel::Type::Helpers::Mutable

        def type
          :multipicklist
        end

        def deserialize(value)
          value.to_s.split(';')
        end

        def serialize(value)
          return if value.blank?

          return value if value.is_a?(::String)

          value.to_a.reject(&:empty?).join(';')
        end
      end
    end
  end
end

ActiveModel::Type.register(:multipicklist, ActiveModel::Type::Salesforce::Multipicklist)
