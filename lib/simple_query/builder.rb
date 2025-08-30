# frozen_string_literal: true

module SimpleQuery
  class Builder
    include SimpleQuery::Stream::PostgresStream
    include SimpleQuery::Stream::MysqlStream

    attr_reader :model, :arel_table

    def initialize(source)
      @model = source
      @arel_table = @model.arel_table

      @selects = []
      @wheres = WhereClause.new(@arel_table)
      @joins = JoinClause.new
      @group_having = GroupHavingClause.new(@arel_table)
      @orders = OrderClause.new(@arel_table)
      @limits = LimitOffsetClause.new
      @distinct_flag = DistinctClause.new
      @aggregations = AggregationClause.new(@arel_table)

      @query_cache = {}
      @query_built = false
      @read_model_class = nil
      @result_struct = nil
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

    def join(table1, table2, foreign_key:, primary_key:, type: :inner)
      @joins.add(table1, table2, foreign_key: foreign_key, primary_key: primary_key, join_type: type)
      reset_query
      self
    end

    def left_join(table1, table2, foreign_key:, primary_key:)
      join(table1, table2, foreign_key: foreign_key, primary_key: primary_key, type: :left)
    end

    def right_join(table1, table2, foreign_key:, primary_key:)
      join(table1, table2, foreign_key: foreign_key, primary_key: primary_key, type: :right)
    end

    def full_join(table1, table2, foreign_key:, primary_key:)
      join(table1, table2, foreign_key: foreign_key, primary_key: primary_key, type: :full)
    end

    def order(order_conditions)
      @orders.add(order_conditions)
      reset_query
      self
    end

    def limit(number)
      @limits.with_limit(number)
      reset_query
      self
    end

    def offset(number)
      @limits.with_offset(number)
      reset_query
      self
    end

    def distinct
      @distinct_flag.set_distinct
      reset_query
      self
    end

    def group(*fields)
      @group_having.add_group(*fields)
      reset_query
      self
    end

    def having(condition)
      @group_having.add_having(condition)
      reset_query
      self
    end

    # Aggregation methods
    def count(column = nil, alias_name: nil)
      @aggregations.count(column, alias_name: alias_name)
      reset_query
      self
    end

    def sum(column, alias_name: nil)
      @aggregations.sum(column, alias_name: alias_name)
      reset_query
      self
    end

    def avg(column, alias_name: nil)
      @aggregations.avg(column, alias_name: alias_name)
      reset_query
      self
    end

    def min(column, alias_name: nil)
      @aggregations.min(column, alias_name: alias_name)
      reset_query
      self
    end

    def max(column, alias_name: nil)
      @aggregations.max(column, alias_name: alias_name)
      reset_query
      self
    end

    def variance(column, alias_name: nil)
      @aggregations.variance(column, alias_name: alias_name)
      reset_query
      self
    end

    def stddev(column, alias_name: nil)
      @aggregations.stddev(column, alias_name: alias_name)
      reset_query
      self
    end

    def group_concat(column, separator: ",", alias_name: nil)
      @aggregations.group_concat(column, separator: separator, alias_name: alias_name)
      reset_query
      self
    end

    def custom_aggregation(expression, alias_name)
      @aggregations.custom(expression, alias_name)
      reset_query
      self
    end

    # Convenience methods for common aggregation patterns
    def total_count(alias_name: "total")
      count(alias_name: alias_name)
    end

    def stats(column, alias_prefix: nil)
      prefix = alias_prefix || column.to_s
      count(alias_name: "#{prefix}_count")
      sum(column, alias_name: "#{prefix}_sum")
      avg(column, alias_name: "#{prefix}_avg")
      min(column, alias_name: "#{prefix}_min")
      max(column, alias_name: "#{prefix}_max")
      self
    end

    # Method to get first/top record by column
    def first_by(column, alias_name: nil)
      alias_name ||= "first_#{column}"
      custom_aggregation("FIRST_VALUE(#{resolve_column_name(column)}) OVER (ORDER BY #{resolve_column_name(column)})",
                         alias_name)
    end

    # Method to get last/bottom record by column
    def last_by(column, alias_name: nil)
      alias_name ||= "last_#{column}"
      custom_aggregation("LAST_VALUE(#{resolve_column_name(column)}) OVER (ORDER BY #{resolve_column_name(column)})",
                         alias_name)
    end

    # Percentage calculations
    def percentage_of_total(column, alias_name: nil)
      alias_name ||= "#{column}_percentage"
      column_expr = resolve_column_name(column)
      expression = "ROUND((#{column_expr} * 100.0 / SUM(#{column_expr}) OVER ()), 2)"
      custom_aggregation(expression, alias_name)
    end

    def map_to(klass)
      @read_model_class = klass
      reset_query
      self
    end

    def bulk_update(set:)
      table_name = @arel_table.name
      set_sql = SetClause.new(set).to_sql

      raise ArgumentError, "No columns to update" if set_sql.empty?

      where_sql = build_where_sql
      sql = "UPDATE #{table_name} SET #{set_sql}"
      sql += " WHERE #{where_sql}" unless where_sql.nil? || where_sql.empty?

      ActiveRecord::Base.connection.execute(sql)
    end

    def stream_each(batch_size: 1000, &block)
      adapter = ActiveRecord::Base.connection.adapter_name.downcase
      if adapter.include?("postgres")
        stream_each_postgres(batch_size, &block)
      elsif adapter.include?("mysql")
        stream_each_mysql(&block)
      else
        raise "stream_each is only implemented for Postgres and MySQL."
      end
    end

    def execute
      records = ActiveRecord::Base.connection.select_all(cached_sql)
      build_result_objects_from_rows(records)
    end

    def lazy_execute
      Enumerator.new do |yielder|
        records = ActiveRecord::Base.connection.select_all(cached_sql)
        if @read_model_class
          build_read_models_enumerator(records, yielder)
        else
          struct = result_struct(records.columns)
          records.rows.each do |row_array|
            yielder << struct.new(*row_array)
          end
        end
      end
    end

    def build_query
      return @query if @query_built

      @query = Arel::SelectManager.new(Arel::Table.engine)
      @query.from(@arel_table)

      # Combine regular selects with aggregations
      all_selects = build_select_expressions
      @query.project(*all_selects)

      apply_distinct
      apply_where_conditions
      apply_joins
      apply_group_and_having
      apply_order_conditions
      apply_limit_and_offset

      @query_built = true
      @query
    end

    private

    def build_select_expressions
      expressions = []

      # Add regular selects
      if @selects.any?
        expressions.concat(@selects)
      elsif @aggregations.empty?
        # Only use * if no aggregations and no explicit selects
        expressions << @arel_table[Arel.star]
      end

      # Add aggregation expressions
      expressions.concat(@aggregations.to_arel_expressions)

      expressions
    end

    def build_where_sql
      condition = @wheres.to_arel
      return "" unless condition

      condition.to_sql
    end

    def reset_query
      @query_built = false
      @query_cache.clear
    end

    def cached_sql
      key = [
        @selects,
        @wheres.conditions,
        @joins.joins,
        @group_having.group_fields,
        @group_having.having_conditions,
        @orders.orders,
        @limits.limit_value,
        @limits.offset_value,
        @distinct_flag.use_distinct?,
        @aggregations.aggregations
      ]

      @query_cache[key] ||= build_query.to_sql
    end

    def build_result_objects_from_rows(records)
      if @read_model_class
        build_read_models_from_arrays(records)
      else
        struct = result_struct(records.columns)
        records.rows.map { |row_array| struct.new(*row_array) }
      end
    end

    def build_read_models_from_arrays(records)
      columns = records.columns
      column_map = columns.each_with_index.to_h
      rows = records.rows

      rows.map do |row_array|
        obj = @read_model_class.allocate
        @read_model_class.attributes.each do |attr_name, col_name|
          idx = column_map[col_name]
          obj.instance_variable_set(:"@#{attr_name}", row_array[idx]) if idx
        end
        obj
      end
    end

    def build_read_models_enumerator(records, yielder)
      columns = records.columns
      column_map = columns.each_with_index.to_h
      records.rows.each do |row_array|
        obj = @read_model_class.allocate
        @read_model_class.attributes.each do |attr_name, col_name|
          idx = column_map[col_name]
          obj.instance_variable_set(:"@#{attr_name}", row_array[idx]) if idx
        end
        yielder << obj
      end
    end

    def result_struct(columns)
      @result_struct ||= Struct.new(*columns.map(&:to_sym))
    end

    def apply_distinct
      @distinct_flag.apply_to(@query)
    end

    def apply_where_conditions
      condition = @wheres.to_arel
      @query.where(condition) if condition
    end

    def apply_joins
      @joins.apply_to(@query)
    end

    def apply_group_and_having
      @group_having.apply_to(@query)
    end

    def apply_order_conditions
      @orders.apply_to(@query)
    end

    def apply_limit_and_offset
      @limits.apply_to(@query)
    end

    def parse_select_field(field)
      case field
      when Symbol
        @arel_table[field]
      when String
        Arel.sql(field)
      when Arel::Nodes::Node
        field
      else
        raise ArgumentError, "Unsupported select field type: #{field.class}"
      end
    end

    def resolve_column_name(column)
      case column
      when Symbol
        "#{@arel_table.name}.#{column}"
      when String
        column.include?(".") ? column : "#{@arel_table.name}.#{column}"
      else
        column.to_s
      end
    end

    def method_missing(method_name, *args, &block)
      if (scope_block = find_scope(method_name))
        instance_exec(*args, &scope_block)
        self
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      !!find_scope(method_name) || super
    end

    def find_scope(method_name)
      return unless model.respond_to?(:_simple_scopes)

      model._simple_scopes[method_name.to_sym]
    end
  end
end
