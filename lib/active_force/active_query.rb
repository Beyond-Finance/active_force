require 'active_support/all'
require 'active_force/query'
require 'forwardable'

module ActiveForce
  class PreparedStatementInvalid < ArgumentError; end

  class UnknownFieldError < StandardError
    def initialize(object, field)
      super("unknown field '#{field}' for #{object.name}")
    end
  end

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

    attr_reader :sobject, :association_mapping, :belongs_to_association_mapping

    def_delegators :sobject, :sfdc_client, :build, :table_name, :mappings
    def_delegators :to_a, :blank?, :present?, :any?, :each, :map, :inspect, :pluck, :each_with_object

    def initialize(sobject, custom_table_name = nil)
      @sobject = sobject
      @association_mapping = {}
      @belongs_to_association_mapping = {}
      super custom_table_name || table_name
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
      sfdc_client.query(super.to_s).first.expr0
    end

    def sum(field)
      raise ArgumentError, 'field is required' if field.blank?
      raise UnknownFieldError.new(sobject, field) unless mappings.key?(field.to_sym)

      sfdc_client.query(super(mappings.fetch(field.to_sym)).to_s).first.expr0
    end

    def limit limit
      limit == 1 ? super.to_a.first : super
    end

    def first
      super.to_a.first
    end

    def not args=nil, *rest
      return self if args.nil?

      super build_condition args, rest
    end

    def where args=nil, *rest
      return self if args.nil?
      super build_condition args, rest
    end

    def select *selected_fields
      selected_fields.map! { |field| mappings[field] }
      super *selected_fields
    end

    def ids
      clone_and_set_instance_variables(query_fields: ["Id"])
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
      includes_query = Association::EagerLoadBuilderForNestedIncludes.build(relations, sobject)
      fields includes_query[:fields]
      association_mapping.merge!(includes_query[:association_mapping])
      self
    end

    def none
      clone_and_set_instance_variables(
        records: [],
        conditions: [build_condition(id: '1' * 18), build_condition(id: '0' * 18)]
      )
    end

    def loaded?
      !@records.nil?
    end

    def order *args
      return self if args.nil?
      super build_order_by args
    end

    private

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
      hash.flat_map do |key, value|
        field = mappings[key]
        raise UnknownFieldError.new(sobject, key) if field.blank?

        applicable_predicates(field, value)
      end
    end

    def applicable_predicates(attribute, value)
      if value.is_a?(Array)
        [in_predicate(attribute, value)]
      elsif value.is_a?(Range)
        range_predicates(attribute, value)
      else
        [eq_predicate(attribute, value)]
      end
    end

    def in_predicate(attribute, values)
      escaped_values = values.map &method(:enclose_value)
      "#{attribute} IN (#{escaped_values.join(',')})"
    end

    def eq_predicate(attribute, value)
      "#{attribute} = #{enclose_value value}"
    end

    def range_predicates(attribute, range)
      conditions = []
      conditions << "#{attribute} >= #{enclose_value(range.begin)}" unless range.begin.nil?
      unless range.end.nil?
        operator = range.exclude_end? ? '<' : '<='
        conditions << "#{attribute} #{operator} #{enclose_value(range.end)}"
      end
      conditions
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
