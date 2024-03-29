require 'active_model'
require 'active_force/active_query'
require 'active_force/association'
require 'active_force/bulk'
require 'active_force/mapping'
require 'yaml'
require 'forwardable'
require 'logger'
require 'restforce'
require 'active_model/attribute/uninitialized_value'

module ActiveForce
  class RecordInvalid < StandardError;end

  class SObject
    include ActiveModel::API
    include ActiveModel::AttributeMethods
    include ActiveModel::Attributes
    include ActiveModel::Model
    include ActiveModel::Dirty
    extend ActiveModel::Callbacks
    include ActiveModel::Serializers::JSON
    extend ActiveForce::Association
    extend ActiveForce::Bulk


    define_model_callbacks :build, :create, :update, :save, :destroy

    class_attribute :mappings, :table_name

    attr_accessor :id, :title

    class << self
      extend Forwardable
      def_delegators :query, :not, :or, :where, :first, :last, :all, :find, :find!, :find_by, :find_by!, :sum, :count, :includes, :limit, :order, :select, :none
      def_delegators :mapping, :table, :table_name, :custom_table?, :mappings

      def update(id, attributes)
        prepare_for_update(id, attributes).update
      end

      def update!(id, attributes)
        prepare_for_update(id, attributes).update!
      end

      private

      def prepare_for_update(id, attributes)
        new(attributes.merge(id: id)).tap do |obj|
          attributes.each do |name, value|
            obj.public_send("#{name}_will_change!") if value.nil?
          end
        end
      end

      ###
      # Provide each subclass with a default id field. Can be overridden
      # in the subclass if needed
      def inherited(subclass)
        subclass.field :id, from: 'Id'
      end
    end

    def self.mapping
      @mapping ||= ActiveForce::Mapping.new name
    end

    def self.fields
      mapping.sfdc_names
    end

    def self.query
      ActiveForce::ActiveQuery.new self
    end

    def self.describe
      sfdc_client.describe(table_name)
    end

    attr_accessor :build_attributes
    def self.build mash, association_mapping={}
      return unless mash
      sobject = new

      attributes_not_selected = sobject.class.fields.reject{|key| mash.keys.include?(key)}
      sobject.uninitialize_attributes(attributes_not_selected)
      sobject.build_attributes = mash[:build_attributes] || mash
      sobject.run_callbacks(:build) do
        mash.each do |column, value|
          if association_mapping.has_key?(column.downcase)
            column = association_mapping[column.downcase]
          end
          sobject.write_value column, value, association_mapping
        end
      end
      sobject.clear_changes_information
      sobject
    end

    def update_attributes! attributes = {}
      assign_attributes attributes
      validate!
      run_callbacks :save do
        run_callbacks :update do
          sfdc_client.update! table_name, attributes_for_sfdb
          clear_changes_information
        end
      end
      true
    end

    alias_method :update!, :update_attributes!

    def update_attributes attributes = {}
      update_attributes! attributes
    rescue Faraday::ClientError, RecordInvalid => error
      handle_save_error error
    end

    alias_method :update, :update_attributes

    def create!
      validate!
      run_callbacks :save do
        run_callbacks :create do
          self.id = sfdc_client.create! table_name, attributes_for_sfdb
          clear_changes_information
        end
      end
      self
    end

    def uninitialize_attributes(attrs)
      return if attrs.blank?
      self.instance_variable_get(:@attributes).instance_variable_get(:@attributes).each do |key, value|
        if attrs.include?(self.mappings.dig(value.name.to_sym))
          self.instance_variable_get(:@attributes).instance_variable_get(:@attributes)[key] = ActiveModel::Attribute::UninitializedValue.new(value.name, value.type)
        else
          key
        end
      end
    end

    def create
      create!
    rescue Faraday::ClientError, RecordInvalid => error
      handle_save_error error
      self
    end

    def destroy
      run_callbacks(:destroy) do
        sfdc_client.destroy! self.class.table_name, id
      end
    end

    def self.create args
      new(args).create
    end

    def self.create! args
      new(args).create!
    end

    def save!
      run_callbacks :save do
        if persisted?
          !!update!
        else
          !!create!
        end
      end
    end

    def save
      save!
    rescue Faraday::ClientError, RecordInvalid => error
      handle_save_error error
    end

    def to_param
      id
    end

    def persisted?
      !!id
    end

    def self.field field_name, args = {}
      options = args.except(:as, :from, :sfdc_name)
      mapping.field field_name, args
      cast_type = args.fetch(:as, :string)
      attribute field_name, cast_type, **options
      define_attribute_methods field_name
    end

    def modified_attributes
      attributes.select{ |attr, key| changed.include? attr.to_s }
    end

    def reload
      association_cache.clear
      reloaded = self.class.find(id)
      self.attributes = reloaded.attributes
      clear_changes_information
      self
    end

    def write_value(key, value, association_mapping = {})
      if (association = self.class.find_association(key.to_sym))
        write_association_value(association, value, association_mapping)
      else
        write_field_value(key, value)
      end
    end

    def [](name)
      send(name.to_sym)
    end

    def []=(name,value)
      send("#{name.to_sym}=", value)
    end

    private

    def validate!
      unless valid?
        raise RecordInvalid.new(
          "Validation failed: #{errors.full_messages.join(', ')}"
        )
      end
    end

    def write_association_value(association, value, association_mapping)
      association_cache[association.relation_name] = Association::RelationModelBuilder.build(association, value,
                                                                                             association_mapping)
    end

    def write_field_value(field_key, value)
      field = if mappings.key?(field_key.to_sym)
                field_key
              else
                mappings.key(field_key)
              end

      send("#{field}=", value) if field && respond_to?(field)
    end

    def handle_save_error error
      return false if error.class == RecordInvalid
      logger_output __method__, error, attributes
    end

    def association_cache
      @association_cache ||= {}
    end

    def logger_output action, exception, params = {}
      logger = Logger.new(STDOUT)
      logger.info("[SFDC] [#{self.class.model_name}] [#{self.class.table_name}] Error while #{ action }, params: #{params}, error: #{exception.inspect}")
      errors.add(:base, exception.message)
      false
    end

    def attributes_for_sfdb
      attrs_to_change = persisted? ? attributes_for_update : attributes_for_create
      self.class.mapping.translate_to_sf(@attributes.values_for_database.slice(*attrs_to_change))
    end

    def attributes_for_create
      default_attributes.concat(changed)
    end

    def default_attributes
      @attributes.each_value.select do |value|
        value.is_a?(ActiveModel::Attribute::UserProvidedDefault) || value.instance_values["original_attribute"].is_a?(ActiveModel::Attribute::UserProvidedDefault)
      end.map(&:name)
    end

    def attributes_for_update
      ['id'].concat(changed)
    end

    def self.picklist field
      picks = sfdc_client.picklist_values(table_name, mappings[field])
      picks.map do |value|
        [value[:label], value[:value]]
      end
    end

    def self.sfdc_client
      ActiveForce.sfdc_client
    end

    def sfdc_client
      self.class.sfdc_client
    end
  end

end
