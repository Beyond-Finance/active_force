require 'active_model'
require 'active_force/active_query'
require 'active_force/association'
require 'active_force/mapping'
require 'active_force/composite/traversable'
require 'active_force/composite/treeable'
require 'yaml'
require 'forwardable'
require 'logger'
require 'restforce'

module ActiveForce
  class RecordInvalid < StandardError;end

  class SObject
    include ActiveModel::API
    include ActiveModel::AttributeMethods
    include ActiveModel::Attributes
    include ActiveModel::Model
    include ActiveModel::Dirty
    include Composite::Traversable
    extend ActiveModel::Callbacks
    include ActiveModel::Serializers::JSON
    extend ActiveForce::Association
    extend Composite::Treeable


    define_model_callbacks :build, :create, :update, :save, :destroy

    class_attribute :mappings, :table_name

    attr_accessor :id, :title

    class << self
      extend Forwardable
      def_delegators :query, :not, :or, :where, :first, :last, :all, :find, :find!, :find_by, :find_by!, :sum, :count, :includes, :limit, :order, :select, :none
      def_delegators :mapping, :table, :table_name, :custom_table?, :mappings

      private

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
      sobject.build_attributes = mash[:build_attributes] || mash
      sobject.run_callbacks(:build) do
        mash.each do |column, value|
          if association_mapping.has_key?(column.downcase)
            column = association_mapping[column.downcase]
          end
          sobject.write_value column, value
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

    def write_value key, value
      if association = self.class.find_association(key.to_sym)
        field = association.relation_name
        value = Association::RelationModelBuilder.build(association, value)
      elsif key.to_sym.in?(mappings.keys)
        # key is a field name
        field = key
      else
        # Assume key is an SFDC column
        field = mappings.key(key)
      end
      send "#{field}=", value if field && respond_to?(field)
    end

    def [](name)
      send(name.to_sym)
    end

    def []=(name,value)
      send("#{name.to_sym}=", value)
    end

    def save_request
      {
        method: persisted? ? 'PATCH' : 'POST',
        url: save_request_url,
        body: attributes_for_sfdb
      }
    end

   private

    def validate!
      unless valid?
        raise RecordInvalid.new(
          "Validation failed: #{errors.full_messages.join(', ')}"
        )
      end
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
      attrs = self.class.mapping.translate_to_sf(@attributes.values_for_database.slice(*changed))
      attrs.merge!({'Id' => id }) if persisted?
      attrs
    end

    def save_request_url
      suffix = persisted? ? "/#{id}" : ''
      "/services/data/sobjects/v#{ActiveForce.sf_api_version}/#{table_name}#{suffix}"
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
