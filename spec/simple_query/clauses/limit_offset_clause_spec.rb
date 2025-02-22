# frozen_string_literal: true

require "spec_helper"

RSpec.describe SimpleQuery::LimitOffsetClause do
  let(:clause) { described_class.new }

  describe "#initialize" do
    it "has nil limit and offset by default" do
      expect(clause.limit_value).to be_nil
      expect(clause.offset_value).to be_nil
    end
  end

  describe "#with_limit" do
    it "sets a positive integer limit" do
      clause.with_limit(10)
      expect(clause.limit_value).to eq(10)
    end

    it "raises ArgumentError if the limit is not a positive integer" do
      expect { clause.with_limit(0) }.to raise_error(ArgumentError, /must be a positive integer/)
    end
  end

  describe "#with_offset" do
    it "sets a non-negative integer offset" do
      clause.with_offset(5)
      expect(clause.offset_value).to eq(5)
    end

    it "raises ArgumentError if the offset is negative" do
      expect { clause.with_offset(-1) }.to raise_error(ArgumentError, /must be a non-negative integer/)
    end
  end

  describe "#apply_to" do
    it "applies limit and offset to the query" do
      clause.with_limit(5)
      clause.with_offset(2)

      arel_manager = Arel::SelectManager.new(Arel::Table.engine)
      arel_manager.from(Arel::Table.new(:users))

      clause.apply_to(arel_manager)
      sql = arel_manager.to_sql

      expect(sql).to match(/LIMIT 5/i)
      expect(sql).to match(/OFFSET 2/i)
    end

    it "applies only limit if offset is not set" do
      clause.with_limit(5)
      arel_manager = Arel::SelectManager.new(Arel::Table.engine)
      arel_manager.from(Arel::Table.new(:users))
      clause.apply_to(arel_manager)
      sql = arel_manager.to_sql
      expect(sql).to match(/LIMIT 5/i)
      expect(sql).not_to match(/OFFSET/i)
    end
  end
end
