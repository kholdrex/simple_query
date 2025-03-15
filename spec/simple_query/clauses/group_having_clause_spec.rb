# frozen_string_literal: true

require "spec_helper"

RSpec.describe SimpleQuery::GroupHavingClause do
  let(:table) { Arel::Table.new(:users) }
  let(:clause) { described_class.new(table) }

  describe "#initialize" do
    it "starts with empty group fields and no having conditions" do
      expect(clause.instance_variable_get(:@group_fields)).to be_empty
      expect(clause.instance_variable_get(:@having_conditions)).to be_empty
    end
  end

  describe "#add_group" do
    it "adds one or more fields to group by" do
      clause.add_group(:city)
      clause.add_group(:state, :country)
      group_fields = clause.instance_variable_get(:@group_fields)
      expect(group_fields.size).to eq(3)
      expect(group_fields.map(&:name)).to eq(["city", "state", "country"])
    end
  end

  describe "#add_having" do
    it "adds having conditions to the array" do
      clause.add_having(table[:city].eq("Paris"))
      expect(clause.instance_variable_get(:@having_conditions).size).to eq(1)
    end
  end

  describe "#apply_to" do
    it "applies group fields to the query" do
      clause.add_group(:city)
      arel_manager = Arel::SelectManager.new(Arel::Table.engine)
      arel_manager.from(table)
      clause.apply_to(arel_manager)

      sql = arel_manager.to_sql
      expect(sql).to match(/GROUP BY.*users.*city/i)
    end

    it "combines multiple having conditions with AND" do
      clause.add_group(:city)
      clause.add_having(table[:city].eq("Paris"))
      clause.add_having(table[:age].gt(20))

      arel_manager = Arel::SelectManager.new(Arel::Table.engine)
      arel_manager.from(table)
      clause.apply_to(arel_manager)
      sql = arel_manager.to_sql

      expect(sql).to match(/GROUP BY.*users.*city/i)
      expect(sql).to match(/HAVING/i)
      expect(sql).to match(/"users"."city" = 'Paris'/i)
      expect(sql).to match(/"users"."age" > 20/i)
    end

    it "omits HAVING if no conditions exist" do
      clause.add_group(:city)
      arel_manager = Arel::SelectManager.new(Arel::Table.engine)
      arel_manager.from(table)
      clause.apply_to(arel_manager)

      sql = arel_manager.to_sql
      expect(sql).to match(/GROUP BY.*users.*city/i)
      expect(sql).not_to match(/HAVING/i)
    end
  end
end
