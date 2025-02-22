# frozen_string_literal: true

require "spec_helper"

RSpec.describe SimpleQuery::OrderClause do
  let(:users_table) { Arel::Table.new(:users) }
  let(:order_clause) { described_class.new(users_table) }

  describe "#initialize" do
    it "starts with an empty orders array" do
      expect(order_clause.orders).to be_empty
    end
  end

  describe "#add" do
    it "adds a single order condition with :asc direction" do
      order_clause.add(name: :asc)
      expect(order_clause.orders.size).to eq(1)
      expect(order_clause.orders.first).to be_a(Arel::Nodes::Ascending)
    end

    it "adds multiple order conditions" do
      order_clause.add(name: :desc, created_at: :asc)
      expect(order_clause.orders.size).to eq(2)

      directions = order_clause.orders.map(&:class)
      expect(directions).to contain_exactly(Arel::Nodes::Descending, Arel::Nodes::Ascending)
    end

    it "raises an error if direction is invalid" do
      expect do
        order_clause.add(name: :invalid)
      end.to raise_error(ArgumentError, /Invalid order direction/)
    end
  end

  describe "#apply_to" do
    it "appends order nodes to the given Arel query" do
      order_clause.add(name: :desc)

      arel_manager = Arel::SelectManager.new(Arel::Table.engine)
      arel_manager.from(users_table)

      order_clause.apply_to(arel_manager)
      sql = arel_manager.to_sql

      expect(sql).to match(/ORDER BY "users"."name" DESC/i)
    end
  end
end
