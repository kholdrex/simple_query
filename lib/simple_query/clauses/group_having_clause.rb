# frozen_string_literal: true

module SimpleQuery
  class GroupHavingClause
    attr_reader :group_fields, :having_conditions

    def initialize(table)
      @table = table
      @group_fields = []
      @having_conditions = []
    end

    def add_group(*fields)
      @group_fields.concat(fields.map { |f| @table[f] })
    end

    def add_having(condition)
      clause = WhereClause.new(@table)
      clause.add(condition)
      @having_conditions.concat(clause.conditions)
    end

    def apply_to(query)
      @group_fields.each { |g| query.group(g) }
      query.having(WhereClause.combine(@having_conditions)) if @having_conditions.any?
      query
    end
  end
end
