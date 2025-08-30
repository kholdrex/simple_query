# frozen_string_literal: true

module SimpleQuery
  class AggregationClause
    attr_reader :aggregations

    def initialize(table)
      @table = table
      @aggregations = []
    end

    def count(column = nil, alias_name: nil)
      column_expr = column ? resolve_column(column) : "*"
      alias_name ||= column ? "count_#{sanitize_alias(column)}" : "count"

      add_aggregation("COUNT", column_expr, alias_name)
    end

    def sum(column, alias_name: nil)
      raise ArgumentError, "Column is required for SUM aggregation" if column.nil?

      column_expr = resolve_column(column)
      alias_name ||= "sum_#{sanitize_alias(column)}"

      add_aggregation("SUM", column_expr, alias_name)
    end

    def avg(column, alias_name: nil)
      raise ArgumentError, "Column is required for AVG aggregation" if column.nil?

      column_expr = resolve_column(column)
      alias_name ||= "avg_#{sanitize_alias(column)}"

      add_aggregation("AVG", column_expr, alias_name)
    end

    def min(column, alias_name: nil)
      raise ArgumentError, "Column is required for MIN aggregation" if column.nil?

      column_expr = resolve_column(column)
      alias_name ||= "min_#{sanitize_alias(column)}"

      add_aggregation("MIN", column_expr, alias_name)
    end

    def max(column, alias_name: nil)
      raise ArgumentError, "Column is required for MAX aggregation" if column.nil?

      column_expr = resolve_column(column)
      alias_name ||= "max_#{sanitize_alias(column)}"

      add_aggregation("MAX", column_expr, alias_name)
    end

    def custom(expression, alias_name)
      if expression.nil? || alias_name.nil?
        raise ArgumentError,
              "Expression and alias are required for custom aggregation"
      end

      @aggregations << {
        expression: expression,
        alias: alias_name
      }
    end

    # Statistical functions
    def variance(column, alias_name: nil)
      raise ArgumentError, "Column is required for VARIANCE aggregation" if column.nil?

      column_expr = resolve_column(column)
      alias_name ||= "variance_#{sanitize_alias(column)}"

      add_aggregation("VARIANCE", column_expr, alias_name)
    end

    def stddev(column, alias_name: nil)
      raise ArgumentError, "Column is required for STDDEV aggregation" if column.nil?

      column_expr = resolve_column(column)
      alias_name ||= "stddev_#{sanitize_alias(column)}"

      add_aggregation("STDDEV", column_expr, alias_name)
    end

    # Group concatenation (database-specific)
    def group_concat(column, separator: ",", alias_name: nil)
      raise ArgumentError, "Column is required for GROUP_CONCAT aggregation" if column.nil?

      column_expr = resolve_column(column)
      alias_name ||= "group_concat_#{sanitize_alias(column)}"

      # Use database-specific group concatenation
      adapter = ActiveRecord::Base.connection.adapter_name.downcase

      expression = case adapter
                   when /mysql/
                     "GROUP_CONCAT(#{column_expr} SEPARATOR '#{separator}')"
                   when /postgres/
                     "STRING_AGG(#{column_expr}::text, '#{separator}')"
                   when /sqlite/
                     "GROUP_CONCAT(#{column_expr}, '#{separator}')"
                   else
                     # Fallback for other databases
                     "GROUP_CONCAT(#{column_expr})"
                   end

      @aggregations << {
        expression: expression,
        alias: alias_name
      }
    end

    def to_arel_expressions
      @aggregations.map do |agg|
        Arel.sql("#{agg[:expression]} AS #{agg[:alias]}")
      end
    end

    def empty?
      @aggregations.empty?
    end

    def clear
      @aggregations.clear
    end

    private

    def add_aggregation(function, column_expr, alias_name)
      @aggregations << {
        expression: "#{function}(#{column_expr})",
        alias: alias_name
      }
    end

    def resolve_column(column)
      case column
      when Symbol
        "#{@table.name}.#{column}"
      when String
        # Allow table.column format or just column name
        column.include?(".") ? column : "#{@table.name}.#{column}"
      when Arel::Attributes::Attribute
        column.to_sql
      else
        column.to_s
      end
    end

    def sanitize_alias(column)
      column.to_s.gsub(".", "_")
    end
  end
end
