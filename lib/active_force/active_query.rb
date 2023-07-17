require 'active_support/all'
require 'active_force/query'
require 'forwardable'

module ActiveForce
  class PreparedStatementInvalid < ArgumentError; end

  class RecordNotFound < StandardError
    attr_reader :table_name, :conditions

    def initialize(message = nil, table_name = nil, conditions = nil)
      @table_name = table_name
      @conditions = conditions

      super(message)
    end
  end

  class ActiveQuery < Query
    extend Forwardable

    attr_reader :sobject, :association_mapping

    def_delegators :sobject, :sfdc_client, :build, :table_name, :mappings
    def_delegators :to_a, :each, :map, :inspect, :pluck, :each_with_object

    def initialize sobject
      @sobject = sobject
      @association_mapping = {}
      super table_name
      fields sobject.fields
    end

    def to_a
      @decorated_records ||= sobject.try(:decorate, records) || records
    end

    private def records
      @records ||= result.to_a.map { |mash| build mash, association_mapping }
    end

    alias_method :all, :to_a

    def count
      super
      sfdc_client.query(to_s).first.expr0
    end

    def sum field
      super(mappings[field])
      sfdc_client.query(to_s).first.expr0
    end

    def limit limit
      super
      limit == 1 ? to_a.first : self
    end

    def not args=nil, *rest
      return self if args.nil?
      super build_condition args, rest
      self
    end

    def where args=nil, *rest
      return self if args.nil?
      return clone_self_and_clear_cache.where(args, *rest) if @decorated_records.present?
      super build_condition args, rest
      self
    end

    def select *fields
      fields.map! { |field| mappings[field] }
      super *fields
    end

    def find!(id)
      result = find(id)
      raise RecordNotFound.new("Couldn't find #{table_name} with id #{id}", table_name, id: id) if result.nil?

      result
    end

    def find_by conditions
      where(conditions).limit 1
    end

    def find_by!(conditions)
      result = find_by(conditions)
      raise RecordNotFound.new("Couldn't find #{table_name} with #{conditions}", table_name, conditions) if result.nil?

      result
    end

    def includes(*relations)
      relations.each do |relation|
        if relation.is_a?(Hash)
          raise "More than 5 levels of nested includes are not supported" if nested_hash?(relation)
          hash_relation(relation)
        else
          single_relation(relation)
        end
      end
      self
    end
    
    def none
      @records = []
      where(id: '1'*18).where(id: '0'*18)
    end

    def loaded?
      !@records.nil?
    end

    def order *args
      return self if args.nil?
      super build_order_by args
    end

    private

    def nested_hash?(value, depth = 0)
      return false unless value.is_a?(Hash)
    
      return true if depth == 4 # 5 levels of nesting not supported
    
      value.values.any? { |v| nested_hash?(v, depth + 1) }
    end

    def hash_relation(relation)
      relation.each do |key, value|
        association = sobject.associations[key]
        association_name = association.class.name.split('::').last
        if ['HasManyAssociation', 'HasOneAssociation'].include?(association_name)
          sub_query = build_hash_relation(association, value)
          fields << "(#{sub_query[:query]})"
          association_mapping.merge!(sub_query[:association_mapping])
        else
          raise "Invalid nested include #{association}"
        end
      end
    end

    def build_hash_relation(association, nested_includes)
      sub_query = Query.new(association.sfdc_association_field)
      sub_query.fields(association.relation_model.fields)
    
      sub_query_association_mapping = { association.sfdc_association_field.downcase => association.relation_name }
      nested_includes = nested_includes.is_a?(Array) ? nested_includes : [nested_includes]
      nested_includes.each do |nested_include|
        case nested_include
        when Symbol
          nested_association = association.options[:model].camelize.constantize.associations[nested_include]
          sub_query.fields << Association::EagerLoadProjectionBuilder.build(nested_association).join(',')
          sub_query_association_mapping[nested_association.sfdc_association_field.downcase] = nested_association.relation_name
        when Hash
          nested_include.each do |key, value|
            nested_association = association.options[:model].camelize.constantize.associations[key]
            nested_sub_query = build_hash_relation(nested_association, value)
            sub_query.fields << "(#{nested_sub_query[:query]})"
            sub_query_association_mapping.merge!(nested_sub_query[:association_mapping])
          end
        end
      end
      { query: sub_query, association_mapping: sub_query_association_mapping }
    end
    
    def single_relation(relation)
      association = sobject.associations[relation]
      fields Association::EagerLoadProjectionBuilder.build(association)
      association_mapping[association.sfdc_association_field.downcase] = association.relation_name
    end

    def build_condition(args, other=[])
      case args
      when String, Array
        build_condition_from_array other.empty? ? args : ([args] + other)
      when Hash
        build_conditions_from_hash args
      else
        args
      end
    end

    def build_condition_from_array(ary)
      statement, *bind_parameters = ary
      return statement if bind_parameters.empty?
      if bind_parameters.first.is_a? Hash
        replace_named_bind_parameters statement, bind_parameters.first
      else
        replace_bind_parameters statement, bind_parameters
      end
    end

    def replace_named_bind_parameters(statement, bind_parameters)
      statement.gsub(/(:?):([a-zA-Z]\w*)/) do
        key = $2.to_sym
        if bind_parameters.has_key? key
          enclose_value bind_parameters[key]
        else
          raise PreparedStatementInvalid, "missing value for :#{key} in #{statement}"
        end
      end
    end

    def replace_bind_parameters(statement, values)
      raise_if_bind_arity_mismatch statement.count('?'), values.size
      bound = values.dup
      statement.gsub('?') do
        enclose_value bound.shift
      end
    end

    def raise_if_bind_arity_mismatch(expected_var_count, actual_var_count)
      if expected_var_count != actual_var_count
        raise PreparedStatementInvalid, "wrong number of bind variables (#{actual_var_count} for #{expected_var_count})"
      end
    end

    def build_conditions_from_hash(hash)
      hash.map do |key, value|
        applicable_predicate mappings[key], value
      end
    end

    def applicable_predicate(attribute, value)
      if value.is_a? Array
        in_predicate attribute, value
      else
        eq_predicate attribute, value
      end
    end

    def in_predicate(attribute, values)
      escaped_values = values.map &method(:enclose_value)
      "#{attribute} IN (#{escaped_values.join(',')})"
    end

    def eq_predicate(attribute, value)
      "#{attribute} = #{enclose_value value}"
    end

    def enclose_value value
      case value
      when String
        quote_string(value)
      when NilClass
        'NULL'
      when Time
        value.iso8601
      else
        value.to_s
      end
    end

    def quote_string(s)
      "'#{s.gsub(/(['\\])/, '\\\\\\1')}'"
    end

    def result
      sfdc_client.query(self.to_s)
    end

    def clone_self_and_clear_cache
      new_query = self.clone
      new_query.instance_variable_set(:@decorated_records, nil)
      new_query.instance_variable_set(:@records, nil)
      new_query
    end

    def build_order_by(args)
      args.map do |arg|
        case arg
        when Symbol
          mappings[arg].to_s
        when Hash
          arg.map { |key, value| "#{mappings[key]} #{order_type(value)}" }
        else
          arg
        end
      end.join(', ')
    end

    def order_type(type)
      type == :desc ? 'DESC' : 'ASC'
    end

  end
end
