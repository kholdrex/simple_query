# frozen_string_literal: true

module SimpleQuery
  class Builder
    attr_reader :model, :arel_table, :selects, :wheres, :joins, :orders, :limits, :offsets

    def initialize(source)
      @model = source
      @arel_table = @model.arel_table
      @selects = []
      @wheres = WhereClause.new(@arel_table)
      @joins = []
      @orders = []
      @limits = nil
      @offsets = nil
      @distinct_flag = false
      @query_cache = {}
      @result_struct = nil
      @query_built = false
      @read_model_class = nil
    end

    def select(*fields)
      @selects.concat(fields.map { |field| parse_select_field(field) })
      reset_query
      self
    end

    def where(condition)
      @wheres.add(condition)
      reset_query
      self
    end

    def join(table1, table2, foreign_key:, primary_key:)
      @joins << {
        table1: arel_table(table1),
        table2: arel_table(table2),
        foreign_key: foreign_key,
        primary_key: primary_key
      }
      reset_query
      self
    end

    def order(order_conditions)
      @orders.concat(parse_order_conditions(order_conditions))
      reset_query
      self
    end

    def limit(number)
      validate_positive_integer(number, "LIMIT")
      @limits = number
      reset_query
      self
    end

    def offset(number)
      validate_non_negative_integer(number, "OFFSET")
      @offsets = number
      reset_query
      self
    end

    def distinct
      @distinct_flag = true
      reset_query
      self
    end

    def map_to(klass)
      @read_model_class = klass
      reset_query
      self
    end

    def execute
      records = ActiveRecord::Base.connection.select_all(cached_sql)
      build_result_objects(records)
    end

    def lazy_execute
      Enumerator.new do |yielder|
        records = ActiveRecord::Base.connection.select_all(cached_sql)
        if @read_model_class
          records.each do |row_hash|
            yielder << @read_model_class.build_from_row(row_hash)
          end
        else
          struct = result_struct(records.columns)
          records.rows.each { |row| yielder << struct.new(*row) }
        end
      end
    end

    def build_query
      return @query if @query_built

      @query = Arel::SelectManager.new(Arel::Table.engine)
      @query.from(@arel_table)

      @query.project(*(@selects.empty? ? [@arel_table[Arel.star]] : @selects))
      @query.distinct if @distinct_flag

      apply_where_conditions
      apply_joins
      apply_order_conditions
      apply_limit_and_offset

      @query_built = true
      @query
    end

    private

    def reset_query
      @query_built = false
      @query_cache.clear
    end

    def cached_sql
      @query_cache[@wheres] ||= build_query.to_sql
    end

    def build_result_objects(records)
      if @read_model_class
        records.map do |row_hash|
          @read_model_class.build_from_row(row_hash)
        end
      else
        struct = result_struct(records.columns)
        records.rows.map { |row| struct.new(*row) }
      end
    end

    def result_struct(columns)
      @result_struct ||= Struct.new(*columns.map(&:to_sym))
    end

    def parse_select_field(field)
      case field
      when Symbol then @arel_table[field]
      when String then Arel.sql(field)
      when Arel::Nodes::Node then field
      else
        raise ArgumentError, "Unsupported select field type: #{field.class}"
      end
    end

    def parse_where_condition(condition)
      case condition
      when Hash then condition.map { |field, value| @arel_table[field].eq(value) }
      when Arel::Nodes::Node then [condition]
      else [Arel.sql(condition.to_s)]
      end
    end

    def arel_table(table)
      table.is_a?(Arel::Table) ? table : Arel::Table.new(table)
    end

    def parse_order_conditions(order_conditions)
      order_conditions.map do |field, direction|
        validate_order_direction(direction)
        @arel_table[field].send(direction)
      end
    end

    def validate_order_direction(direction)
      return if [:asc, :desc].include?(direction)

      raise ArgumentError, "Invalid order direction: #{direction}. Use :asc or :desc."
    end

    def validate_positive_integer(number, label)
      raise ArgumentError, "#{label} must be a positive integer" unless number.is_a?(Integer) && number.positive?
    end

    def validate_non_negative_integer(number, label)
      raise ArgumentError, "#{label} must be a non-negative integer" unless number.is_a?(Integer) && number >= 0
    end

    def apply_where_conditions
      condition = @wheres.to_arel
      @query.where(condition) if condition
    end

    def apply_joins
      @joins.each do |join|
        @query.join(join[:table2]).on(
          join[:table2][join[:foreign_key]].eq(join[:table1][join[:primary_key]])
        )
      end
    end

    def apply_order_conditions
      @orders.each { |order| @query.order(order) }
    end

    def apply_limit_and_offset
      @query.take(@limits) if @limits
      @query.skip(@offsets) if @offsets
    end
  end
end
