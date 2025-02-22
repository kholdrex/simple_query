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
      @having_conditions << condition
    end

    def apply_to(query)
      @group_fields.each { |g| query.group(g) }
      if @having_conditions.any?
        combined = @having_conditions.inject { |c, a| c.and(a) }
        query.having(combined)
      end
      query
    end
  end
end
