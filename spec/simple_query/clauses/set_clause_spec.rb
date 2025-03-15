# frozen_string_literal: true

require "spec_helper"

RSpec.describe SimpleQuery::SetClause do
  describe "#to_sql" do
    it "builds a simple set clause for strings and booleans" do
      clause = described_class.new({ name: "Alice", active: false })
      sql = clause.to_sql

      expect(sql).to match(/name.*=.*'Alice'/)
      expect(sql).to match(/active.*=.*(0|false|f|FALSE|TRUE|1)/i)
      expect(sql).to include(",")
    end

    it "quotes column names with special chars" do
      clause = described_class.new({ "weird column" => "val" })
      sql = clause.to_sql

      expect(sql).to match(/weird column.*=.*'val'/i)
    end

    it "handles multiple columns" do
      clause = described_class.new(
        status: "archived",
        updated_at: Time.new(2025, 2, 15, 10, 30)
      )
      sql = clause.to_sql

      expect(sql).to match(/status.*=.*'archived'/i)
      expect(sql).to match(/updated_at.*=\s*'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'/)
      expect(sql).to include(",")
    end

    it "returns an empty string if set_hash is empty" do
      clause = described_class.new({})
      sql = clause.to_sql
      expect(sql).to eq("")
    end
  end
end
