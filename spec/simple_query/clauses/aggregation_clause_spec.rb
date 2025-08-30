# frozen_string_literal: true

require "spec_helper"

RSpec.describe SimpleQuery::AggregationClause do
  let(:table) { Arel::Table.new(:users) }
  let(:aggregation_clause) { described_class.new(table) }

  describe "#count" do
    it "adds count aggregation without column" do
      aggregation_clause.count

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.size).to eq(1)
      expect(expressions.first.to_s).to match(/COUNT\(\*\) AS count/i)
    end

    it "adds count aggregation with column" do
      aggregation_clause.count(:id)

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.size).to eq(1)
      expect(expressions.first.to_s).to match(/COUNT\(users\.id\) AS count_id/i)
    end

    it "adds count aggregation with custom alias" do
      aggregation_clause.count(:email, alias_name: "total_emails")

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.size).to eq(1)
      expect(expressions.first.to_s).to match(/COUNT\(users\.email\) AS total_emails/i)
    end
  end

  describe "#sum" do
    it "adds sum aggregation" do
      aggregation_clause.sum(:annual_revenue)

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.size).to eq(1)
      expect(expressions.first.to_s).to match(/SUM\(users\.annual_revenue\) AS sum_annual_revenue/i)
    end

    it "raises error without column" do
      expect { aggregation_clause.sum(nil) }.to raise_error(ArgumentError, /Column is required/)
    end

    it "accepts custom alias" do
      aggregation_clause.sum(:revenue, alias_name: "total_revenue")

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.first.to_s).to match(/SUM\(users\.revenue\) AS total_revenue/i)
    end
  end

  describe "#avg" do
    it "adds average aggregation" do
      aggregation_clause.avg(:score)

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.size).to eq(1)
      expect(expressions.first.to_s).to match(/AVG\(users\.score\) AS avg_score/i)
    end

    it "raises error without column" do
      expect { aggregation_clause.avg(nil) }.to raise_error(ArgumentError, /Column is required/)
    end
  end

  describe "#min" do
    it "adds minimum aggregation" do
      aggregation_clause.min(:created_at)

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.size).to eq(1)
      expect(expressions.first.to_s).to match(/MIN\(users\.created_at\) AS min_created_at/i)
    end

    it "raises error without column" do
      expect { aggregation_clause.min(nil) }.to raise_error(ArgumentError, /Column is required/)
    end
  end

  describe "#max" do
    it "adds maximum aggregation" do
      aggregation_clause.max(:updated_at)

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.size).to eq(1)
      expect(expressions.first.to_s).to match(/MAX\(users\.updated_at\) AS max_updated_at/i)
    end

    it "raises error without column" do
      expect { aggregation_clause.max(nil) }.to raise_error(ArgumentError, /Column is required/)
    end
  end

  describe "#variance" do
    it "adds variance aggregation" do
      aggregation_clause.variance(:score)

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.size).to eq(1)
      expect(expressions.first.to_s).to match(/VARIANCE\(users\.score\) AS variance_score/i)
    end
  end

  describe "#stddev" do
    it "adds standard deviation aggregation" do
      aggregation_clause.stddev(:score)

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.size).to eq(1)
      expect(expressions.first.to_s).to match(/STDDEV\(users\.score\) AS stddev_score/i)
    end
  end

  describe "#group_concat" do
    before do
      allow(ActiveRecord::Base.connection).to receive(:adapter_name).and_return(adapter_name)
    end

    context "with MySQL adapter" do
      let(:adapter_name) { "MySQL" }

      it "uses GROUP_CONCAT with SEPARATOR" do
        aggregation_clause.group_concat(:name, separator: "|")

        expressions = aggregation_clause.to_arel_expressions
        expect(expressions.first.to_s).to match(/GROUP_CONCAT\(users\.name SEPARATOR '\|'\) AS group_concat_name/i)
      end
    end

    context "with PostgreSQL adapter" do
      let(:adapter_name) { "PostgreSQL" }

      it "uses STRING_AGG" do
        aggregation_clause.group_concat(:name, separator: ",")

        expressions = aggregation_clause.to_arel_expressions
        expect(expressions.first.to_s).to match(/STRING_AGG\(users\.name::text, ','\) AS group_concat_name/i)
      end
    end

    context "with SQLite adapter" do
      let(:adapter_name) { "SQLite" }

      it "uses GROUP_CONCAT with separator" do
        aggregation_clause.group_concat(:name, separator: ";")

        expressions = aggregation_clause.to_arel_expressions
        expect(expressions.first.to_s).to match(/GROUP_CONCAT\(users\.name, ';'\) AS group_concat_name/i)
      end
    end
  end

  describe "#custom" do
    it "adds custom aggregation expression" do
      aggregation_clause.custom("PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY score)", "median_score")

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.size).to eq(1)
      expect(expressions.first.to_s).to match(
        /PERCENTILE_CONT\(0\.5\) WITHIN GROUP \(ORDER BY score\) AS median_score/i
      )
    end

    it "raises error without expression or alias" do
      expect { aggregation_clause.custom(nil, "test") }.to raise_error(ArgumentError)
      expect { aggregation_clause.custom("COUNT(*)", nil) }.to raise_error(ArgumentError)
    end
  end

  describe "#resolve_column" do
    it "handles symbol columns" do
      aggregation_clause.sum(:revenue)

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.first.to_s).to match(/users\.revenue/)
    end

    it "handles string columns" do
      aggregation_clause.sum("total_amount")

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.first.to_s).to match(/users\.total_amount/)
    end

    it "handles string columns with table prefix" do
      aggregation_clause.sum("companies.annual_revenue")

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.first.to_s).to match(/companies\.annual_revenue/)
    end
  end

  describe "#multiple_aggregations" do
    it "supports multiple aggregations in one clause" do
      aggregation_clause.count
      aggregation_clause.sum(:revenue)
      aggregation_clause.avg(:score)

      expressions = aggregation_clause.to_arel_expressions
      expect(expressions.size).to eq(3)

      sql_expressions = expressions.map(&:to_s)
      expect(sql_expressions).to include(match(/COUNT\(\*\) AS count/i))
      expect(sql_expressions).to include(match(/SUM\(users\.revenue\) AS sum_revenue/i))
      expect(sql_expressions).to include(match(/AVG\(users\.score\) AS avg_score/i))
    end
  end

  describe "#empty?" do
    it "returns true when no aggregations" do
      expect(aggregation_clause.empty?).to be true
    end

    it "returns false when aggregations exist" do
      aggregation_clause.count
      expect(aggregation_clause.empty?).to be false
    end
  end

  describe "#clear" do
    it "removes all aggregations" do
      aggregation_clause.count
      aggregation_clause.sum(:revenue)

      expect(aggregation_clause.empty?).to be false
      aggregation_clause.clear
      expect(aggregation_clause.empty?).to be true
    end
  end
end
