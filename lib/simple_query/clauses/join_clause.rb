# frozen_string_literal: true

module SimpleQuery
  class JoinClause
    attr_reader :joins

    def initialize
      @joins = []
    end

    def add(table1, table2, foreign_key:, primary_key:, join_type: :inner)
      @joins << {
        table1: to_arel_table(table1),
        table2: to_arel_table(table2),
        foreign_key: foreign_key,
        primary_key: primary_key,
        type: join_type
      }
    end

    def apply_to(query)
      @joins.each do |join_def|
        table1 = join_def[:table1]
        table2 = join_def[:table2]
        fk = join_def[:foreign_key]
        pk = join_def[:primary_key]
        type = join_def[:type]

        join_class = case type
                     when :left
                       Arel::Nodes::OuterJoin
                     when :right
                       Arel::Nodes::RightOuterJoin
                     when :full
                       Arel::Nodes::FullOuterJoin
                     else
                       Arel::Nodes::InnerJoin
                     end

        condition = table2[fk].eq(table1[pk])
        query.join(table2, join_class).on(condition)
      end
      query
    end

    private

    def to_arel_table(obj)
      obj.is_a?(Arel::Table) ? obj : Arel::Table.new(obj)
    end
  end
end
