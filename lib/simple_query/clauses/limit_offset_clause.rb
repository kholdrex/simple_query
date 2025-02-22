# frozen_string_literal: true

module SimpleQuery
  class LimitOffsetClause
    attr_reader :limit_value, :offset_value

    def initialize
      @limit_value = nil
      @offset_value = nil
    end

    def with_limit(limit)
      raise ArgumentError, "LIMIT must be a positive integer" unless limit.is_a?(Integer) && limit.positive?

      @limit_value = limit
    end

    def with_offset(offset)
      raise ArgumentError, "OFFSET must be a non-negative integer" unless offset.is_a?(Integer) && offset >= 0

      @offset_value = offset
    end

    def apply_to(query)
      query.take(@limit_value) if @limit_value
      query.skip(@offset_value) if @offset_value
      query
    end
  end
end
