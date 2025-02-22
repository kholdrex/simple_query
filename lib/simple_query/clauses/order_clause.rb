# frozen_string_literal: true

module SimpleQuery
  class OrderClause
    attr_reader :orders

    def initialize(table)
      @table = table
      @orders = []
    end

    def add(order_conditions)
      order_conditions.each do |field, direction|
        validate_order_direction(direction)
        @orders << @table[field].send(direction)
      end
    end

    def apply_to(query)
      @orders.each { |order_node| query.order(order_node) }
      query
    end

    private

    def validate_order_direction(direction)
      return if [:asc, :desc].include?(direction)

      raise ArgumentError, "Invalid order direction: #{direction}. Use :asc or :desc."
    end
  end
end
