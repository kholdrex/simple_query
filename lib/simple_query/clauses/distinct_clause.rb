# frozen_string_literal: true

module SimpleQuery
  class DistinctClause
    def initialize
      @use_distinct = false
    end

    def use_distinct?
      @use_distinct
    end

    def set_distinct
      @use_distinct = true
    end

    def apply_to(query)
      query.distinct if @use_distinct
      query
    end
  end
end
