# frozen_string_literal: true

require "spec_helper"

RSpec.describe SimpleQuery::DistinctClause do
  let(:distinct_clause) { described_class.new }

  describe "#initialize" do
    it "initializes with distinct turned off" do
      expect do
        arel_manager = Arel::SelectManager.new(Arel::Table.engine)
        distinct_clause.apply_to(arel_manager)
      end.not_to raise_error
    end
  end

  describe "#set_distinct" do
    it "enables distinct queries" do
      distinct_clause.set_distinct
      arel_manager = Arel::SelectManager.new(Arel::Table.engine)
      arel_manager.from(Arel::Table.new(:users))

      distinct_clause.apply_to(arel_manager)
      sql = arel_manager.to_sql

      expect(sql).to match(/SELECT DISTINCT/i)
    end
  end
end
