# frozen_string_literal: true

module SimpleQuery
  class JoinClause
    attr_reader :joins

    def initialize
      @joins = []
    end

    def add(table1, table2, foreign_key:, primary_key:)
      @joins << {
        table1: to_arel_table(table1),
        table2: to_arel_table(table2),
        foreign_key: foreign_key,
        primary_key: primary_key
      }
    end

    def apply_to(query)
      @joins.each do |join|
        query.join(join[:table2])
             .on(join[:table2][join[:foreign_key]]
                   .eq(join[:table1][join[:primary_key]]))
      end
      query
    end

    private

    def to_arel_table(obj)
      obj.is_a?(Arel::Table) ? obj : Arel::Table.new(obj)
    end
  end
end
