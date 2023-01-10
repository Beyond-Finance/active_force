module ActiveForce
  class ModelGenerator < Rails::Generators::NamedBase
    desc 'This generator loads the table fields from SFDC and generates the fields for the SObject with a more Ruby name'

    source_root File.expand_path('../templates', __FILE__)
    argument :namespace, type: :string, optional: true, default: ''
    class_option :namespace, type: :string, default: ''


    SALESFORCE_TO_ACTIVEMODEL_TYPE_MAP = {
      'boolean' => :boolean,
      'double' => :float,
      'percentage' => :float,
      'currency' => :float,
      'date' => :date,
      'datetime' => :datetime,
      'int' => :integer,
    }

    def create_model_file
      @namespace = options[:namespace].present? ? options[:namespace] + '::' : options[:namespace]
      @table_name = file_name.capitalize
      @class_name = @namespace + @table_name.gsub('__c', '')
      template "model.rb.erb", "app/models/#{@class_name.underscore}.rb" if table_exists?
    end

    protected

    Attribute = Struct.new :field, :column, :type

    def attributes
      @attributes ||= sfdc_columns.map do |column|
        Attribute.new column_to_field(column.name), column.name, saleforce_to_active_model_type(column.type)
      end
      @attributes - [:id]
    end

    def sfdc_columns
      @columns ||= ActiveForce::SObject.sfdc_client.describe(@table_name).fields
    end

    def table_exists?
      !! sfdc_columns
      rescue Faraday::Error::ResourceNotFound
        puts "The specified table name is not found. Be sure to append __c if it's custom"
    end

    def column_to_field column
      column.underscore.gsub("__c", "").to_sym
    end

    def attribute_line attribute
      "field :#{ attribute.field },#{ space_justify attribute.field }  from: '#{ attribute.column }'#{ add_type(attribute.type) } "
    end

    def space_justify field_name
      longest_field = attributes.map { |attr| attr.field.length } .max
      justify_count = longest_field - field_name.length
      " " * justify_count
    end

    def add_type(type)
      # String is the default so no need to add it
      return '' if type == :string
      ", as: :#{ type }"
    end

    def saleforce_to_active_model_type type
      SALESFORCE_TO_ACTIVEMODEL_TYPE_MAP.fetch(type, :string)
    end
  end
end
