module ActiveForce
  class Query
    attr_reader :table

    def initialize table
      @table = table
      @conditions = []
      @table_id = 'Id'
      @query_fields = [@table_id]
    end

    def fields fields_collection = []
      @query_fields += fields_collection.to_a
    end

    def all
      self
    end

    def to_s
      <<-SOQL.gsub(/\s+/, " ").strip
        SELECT
          #{ build_select }
        FROM
          #{ @table }
        #{ build_where }
        #{ build_order }
        #{ build_limit }
        #{ build_offset }
      SOQL
    end

    def select *columns
      clone_and_set_instance_variables(query_fields: columns)
    end

    def where condition = nil
      new_conditions = @conditions | [condition]
      if new_conditions != @conditions
        clone_and_set_instance_variables({conditions: new_conditions})
      else
        self
      end
    end

    def not condition
      condition ? where("NOT ((#{condition.join(') AND (')}))") : self
    end

    def or query
      return self unless query

      clone_and_set_instance_variables(conditions: ["(#{and_conditions}) OR (#{query.and_conditions})"])
    end

    def order order
      order ? clone_and_set_instance_variables(order: order) : self
    end

    def limit size
      size ? clone_and_set_instance_variables(size: size) : self
    end

    def limit_value
      @size
    end

    def offset offset
      clone_and_set_instance_variables(offset: offset)
    end

    def offset_value
      @offset
    end

    def find id
      where("#{ @table_id } = '#{ id }'").limit 1
    end

    def first
      if @records
        clone_and_set_instance_variables(
          size: 1,
          records: [@records.first],
          decorated_records: [@decorated_records&.first]
        )
      else
        limit(1)
      end
    end

    def last(limit = 1)
      order("Id DESC").limit(limit)
    end

    def join object_query
      chained_query = self.clone
      chained_query.fields ["(#{ object_query.to_s })"]
      chained_query
    end

    def count
      clone_and_set_instance_variables(query_fields: ["count(Id)"])
    end

    def sum field
      clone_and_set_instance_variables(query_fields: ["sum(#{field})"])
    end

    protected
      def and_conditions
        "(#{@conditions.join(') AND (')})" unless @conditions.empty?
      end

      def build_select
        @query_fields.compact.uniq.join(', ')
      end

      def build_where
        "WHERE #{and_conditions}" unless @conditions.empty?
      end

      def build_limit
        "LIMIT #{ @size }" if @size
      end

      def build_order
        "ORDER BY #{ @order }" if @order
      end

      def build_offset
        "OFFSET #{ @offset }" if @offset
      end

      def clone_and_set_instance_variables instance_variable_hash={}
        clone = self.clone
        { decorated_records: @decorated_records, records: @records }
          .merge(instance_variable_hash)
          .each { |k,v| clone.instance_variable_set("@#{k.to_s}", v) }
        clone
      end
  end
end
