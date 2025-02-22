# frozen_string_literal: true

module SimpleQuery
  class WhereClause
    attr_reader :conditions

    def initialize(table)
      @table = table
      @conditions = []
    end

    def add(condition)
      parsed_conditions = parse_condition(condition)
      @conditions.concat(parsed_conditions)
    end

    def to_arel
      return nil if @conditions.empty?
      @conditions.inject do |combined, current|
        combined.and(current)
      end
    end

    private

    def parse_condition(condition)
      case condition
      when Hash
        condition.map { |field, value| @table[field].eq(value) }
      when Arel::Nodes::Node
        [condition]
      else
        [Arel.sql(condition.to_s)]
      end
    end
  end
end
