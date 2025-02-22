# frozen_string_literal: true

require "spec_helper"

RSpec.describe SimpleQuery::WhereClause do
  let(:users_table) { Arel::Table.new(:users) }
  let(:where_clause) { described_class.new(users_table) }

  describe "#add" do
    it "adds a simple equality condition from a hash" do
      where_clause.add(name: "Jane")
      expect(where_clause.conditions.size).to eq(1)
    end

    it "adds multiple conditions from a hash" do
      where_clause.add(name: "Jane", email: "jane@example.com")
      expect(where_clause.conditions.size).to eq(2)
    end

    it "handles a single Arel::Nodes::Node" do
      condition_node = users_table[:active].eq(true)
      where_clause.add(condition_node)
      expect(where_clause.conditions.size).to eq(1)
      expect(where_clause.conditions.first).to eq(condition_node)
    end

    it "handles a string" do
      where_clause.add("users.deleted_at IS NULL")
      expect(where_clause.conditions.size).to eq(1)
    end
  end

  describe "#to_arel" do
    it "returns a combined condition using AND" do
      where_clause.add(active: true)
      where_clause.add(admin: false)
      combined = where_clause.to_arel

      expect(combined).to be_a(Arel::Nodes::And)
    end

    it "returns nil when there are no conditions" do
      expect(where_clause.to_arel).to be_nil
    end
  end
end
