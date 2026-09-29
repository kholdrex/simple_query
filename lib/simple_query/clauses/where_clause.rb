# frozen_string_literal: true

module SimpleQuery
  class WhereClause
    attr_reader :conditions

    def self.combine(conditions)
      return nil if conditions.empty?
      return conditions.first if conditions.one?

      Arel::Nodes::And.new(conditions.map { |c| c.is_a?(Arel::Nodes::Grouping) ? c : Arel::Nodes::Grouping.new(c) })
    end

    def initialize(table, model = ActiveRecord::Base)
      @table = table
      @model = model
      @conditions = []
    end

    def add(condition)
      parsed_conditions = parse_condition(condition)
      @conditions.concat(parsed_conditions)
    end

    def to_arel
      self.class.combine(@conditions)
    end

    private

    def parse_condition(condition)
      case condition
      when Hash
        condition.map { |field, value| hash_predicate(field, value) }
      when Arel::Nodes::Node, Arel::Attributes::Attribute
        [condition]
      when Array
        sanitized_sql = @model.send(:sanitize_sql_array, condition)
        [Arel.sql(sanitized_sql)]
      else
        [Arel.sql(condition.to_s)]
      end
    end

    def hash_predicate(field, value)
      attribute = @table[field]
      return attribute.eq(value) if force_equality?(field, value)

      case value
      when Array
        values = value.compact
        predicate = attribute.in(values)
        values.size == value.size ? predicate : predicate.or(attribute.eq(nil))
      when Range
        attribute.between(value)
      else
        attribute.eq(value)
      end
    end

    # PostgreSQL array/range columns compare arrays and ranges by equality, like ActiveRecord does.
    def force_equality?(field, value)
      @table.able_to_type_cast? && @table.type_for_attribute(field.to_s).force_equality?(value)
    end
  end
end
