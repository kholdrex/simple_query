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
      expect(where_clause.conditions.first.to_s).to include("users.deleted_at IS NULL")
    end

    context "with placeholder arrays" do
      it "handles positional placeholders" do
        where_clause.add(["name LIKE ?", "%John%"])
        expect(where_clause.conditions.size).to eq(1)

        sql_node = where_clause.conditions.first
        expect(sql_node).to be_a(Arel::Nodes::SqlLiteral)
        expect(sql_node.to_s).to match(/name LIKE '%John%'/)
      end

      it "handles named placeholders" do
        where_clause.add(["email = :email", { email: "john@example.com" }])
        expect(where_clause.conditions.size).to eq(1)

        sql_node = where_clause.conditions.first
        expect(sql_node).to be_a(Arel::Nodes::SqlLiteral)
        expect(sql_node.to_s).to match(/email = 'john@example.com'/)
      end

      it "handles multiple placeholders in one condition" do
        where_clause.add(["id >= :min_id AND name LIKE :name", { min_id: 100, name: "%Jane%" }])
        expect(where_clause.conditions.size).to eq(1)

        sql_node = where_clause.conditions.first
        expect(sql_node).to be_a(Arel::Nodes::SqlLiteral)
        expect(sql_node.to_s).to match(/id\s*>=\s*'?100'?/i)
        expect(sql_node.to_s).to match(/name LIKE '%Jane%'/)
      end
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
