module ActiveForce
  class SelectBuilder

    attr_reader :selected_fields, :nested_query_fields, :non_nested_query_fields, :query

    def initialize(selected_fields, query)
      @query = query
      @selected_fields = selected_fields
      @non_nested_query_fields = []
      @nested_query_fields = []
    end

    def parse
      selected_fields.each do |field|
        case field
        when Symbol
          non_nested_query_fields << query.mappings[field]
        when Hash
          populate_nested_query_fields(field)
        when String
          non_nested_query_fields << field
        end
      end
      {non_nested_query_fields: non_nested_query_fields, nested_query_fields: nested_query_fields}
    end

    private

    def populate_nested_query_fields(field)
      field.each do |key, value|
        case value
        when Symbol
          field[key] = [value]
        when Hash
          raise ArgumentError, 'Nested Hash is not supported in select statement, you may wish to use an Array'
        end
      end
      nested_query_fields << field
    end
  end
end
