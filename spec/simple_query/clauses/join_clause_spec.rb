# frozen_string_literal: true

require "spec_helper"

RSpec.describe SimpleQuery::JoinClause do
  let(:join_clause) { described_class.new }

  describe "#add" do
    it "adds a join definition to the list" do
      join_clause.add(:users, :companies, foreign_key: :user_id, primary_key: :id)
      expect(join_clause.joins.size).to eq(1)
      expect(join_clause.joins.first[:table1].name).to eq("users")
      expect(join_clause.joins.first[:table2].name).to eq("companies")
      expect(join_clause.joins.first[:foreign_key]).to eq(:user_id)
      expect(join_clause.joins.first[:primary_key]).to eq(:id)
    end
  end

  describe "#apply_to" do
    it "applies each join to the given Arel::SelectManager" do
      join_clause.add(:users, :companies, foreign_key: :user_id, primary_key: :id)

      users_table = Arel::Table.new(:users)
      arel_manager = Arel::SelectManager.new(Arel::Table.engine)
      arel_manager.from(users_table)

      join_clause.apply_to(arel_manager)

      sql = arel_manager.to_sql
      expect(sql).to match(/JOIN.*companies.*ON.*companies.*user_id.*=.*users.*id/i)
    end

    it "applies multiple joins" do
      join_clause.add(:users, :companies, foreign_key: :user_id, primary_key: :id)
      join_clause.add(:companies, :projects, foreign_key: :company_id, primary_key: :id)

      arel_manager = Arel::SelectManager.new(Arel::Table.engine)
      arel_manager.from(Arel::Table.new(:users))

      join_clause.apply_to(arel_manager)
      sql = arel_manager.to_sql

      expect(sql).to match(/JOIN.*companies/i)
      expect(sql).to match(/JOIN.*projects/i)
    end
  end
end
