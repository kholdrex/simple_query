# frozen_string_literal: true

require "spec_helper"
require "benchmark"

RSpec.describe SimpleQuery::Builder do
  let(:query_object) { described_class.new(User) }

  before(:all) do
    user1 = User.create(name: "Jane Doe", email: "jane@example.com", first_name: "Jane", last_name: "Doe",
                        active: true, admin: true, status: 1)
    user2 = User.create(name: "John Smith", email: "john@example.com", first_name: "John", last_name: "Smith",
                        active: true, admin: false, status: 1)

    company1 = Company.create(name: "TechCorp", user_id: user1.id, registration_number: "TC123", founded_year: 2010,
                              industry: "Technology", active: true, size: 1, status: 0, annual_revenue: 1_000_000)
    company2 = Company.create(name: "BizSoft", user_id: user2.id, registration_number: "BS456", founded_year: 2015,
                              industry: "Software", active: true, size: 0, status: 0, annual_revenue: 500_000)

    Project.create(name: "Project A", company_id: company1.id, status: "active")
    Project.create(name: "Project B", company_id: company2.id, status: "active")

    team1 = Team.create(name: "Team Alpha")
    team2 = Team.create(name: "Team Beta")

    user1.teams << team1
    user2.teams << team2
  end

  describe "#execute" do
    it "returns a simple query result as Struct objects" do
      result = User.simple_query.select(:name, :email).where(name: "Jane Doe").execute
      expect(result.first).to be_an(Struct)
      expect(result.first.name).to eq("Jane Doe")
    end

    it "returns multiple results correctly" do
      result = User.simple_query.select(:name).execute
      expect(result.size).to eq(2)
      expect(result.map(&:name)).to contain_exactly("Jane Doe", "John Smith")
    end

    it "handles joins correctly with explicit foreign keys" do
      result = User.simple_query
                   .select(:name, :email)
                   .join(:users, :companies, foreign_key: :user_id, primary_key: :id)
                   .where(Company.arel_table[:name].eq("TechCorp"))
                   .execute

      expect(result.first).to be_an(Struct)
      expect(result.first.name).to eq("Jane Doe")
    end

    it "returns an empty array when no records match" do
      result = User.simple_query.select(:name).where(name: "Nonexistent").execute
      expect(result).to be_empty
    end

    it "supports multiple joins" do
      result = User.simple_query
                   .select(:name, :email)
                   .join(:users, :companies, foreign_key: :user_id, primary_key: :id)
                   .join(:companies, :projects, foreign_key: :company_id, primary_key: :id)
                   .where(Project.arel_table[:name].eq("Project A"))
                   .execute

      expect(result.first).to be_an(Struct)
      expect(result.first.name).to eq("Jane Doe")
    end

    it "defaults to INNER JOIN if no type is provided" do
      sql = query_object
            .join(:users, :companies, foreign_key: :user_id, primary_key: :id)
            .build_query
            .to_sql
      expect(sql).to match(/INNER JOIN .*companies.* ON .*companies.*user_id.*=.*users.*id/i)
    end

    it "supports left_join" do
      sql = query_object
            .left_join(:users, :companies, foreign_key: :user_id, primary_key: :id)
            .build_query
            .to_sql
      expect(sql).to match(/LEFT OUTER JOIN.*companies.*ON.*companies.*user_id.*=.*users.*id/i)
    end

    it "supports right_join" do
      sql = query_object
            .right_join(:users, :companies, foreign_key: :user_id, primary_key: :id)
            .build_query
            .to_sql
      expect(sql).to match(/RIGHT OUTER JOIN.*companies.*ON.*companies.*user_id.*=.*users.*id/i)
    end

    it "supports full_join" do
      sql = query_object
            .full_join(:users, :companies, foreign_key: :user_id, primary_key: :id)
            .build_query
            .to_sql
      expect(sql).to match(/FULL OUTER JOIN.*companies.*ON.*companies.*user_id.*=.*users.*id/i)
    end

    it "supports DISTINCT queries" do
      User.create(name: "Jane Doe", email: "jane2@example.com")
      result = User.simple_query
                   .select(:name)
                   .distinct
                   .execute
      expect(result.size).to be < User.count
    end

    it "handles complex JOINs with multiple conditions" do
      result = User.simple_query
                   .select(:name)
                   .join(:users, :companies, foreign_key: :user_id, primary_key: :id)
                   .join(:companies, :projects, foreign_key: :company_id, primary_key: :id)
                   .join(:users, :teams_users, foreign_key: :user_id, primary_key: :id)
                   .join(:teams_users, :teams, foreign_key: :id, primary_key: :team_id)
                   .where(Company.arel_table[:industry].eq("Technology"))
                   .where(Project.arel_table[:status].eq("active"))
                   .where(Team.arel_table[:name].eq("Team Alpha"))
                   .execute
      expect(result).not_to be_empty
      expect(result.first.name).to eq("Jane Doe")
    end

    it "executes queries with multiple WHERE conditions" do
      result = User.simple_query
                   .select(:name)
                   .where(name: "Jane Doe")
                   .where(email: "jane@example.com")
                   .execute

      expect(result.first).to be_an(Struct)
      expect(result.first.name).to eq("Jane Doe")
    end

    it "supports basic aggregations" do
      result = Company.simple_query
                      .select(Arel.sql("SUM(annual_revenue) as total_revenue"))
                      .execute
      expect(result.first.total_revenue).to be_a(Numeric)
    end

    context "Enhanced Aggregation Support" do
      describe "#count" do
        it "counts all records" do
          result = User.simple_query.count.execute
          expect(result.first.count).to eq(User.count)
        end

        it "counts specific column" do
          result = User.simple_query.count(:email).execute
          expect(result.first.count_email).to eq(User.where.not(email: nil).count)
        end

        it "counts with custom alias" do
          result = User.simple_query.count(:id, alias_name: "total_users").execute
          expect(result.first.total_users).to eq(User.count)
        end

        it "counts with where conditions" do
          result = User.simple_query.where(active: true).count.execute
          expect(result.first.count).to eq(User.where(active: true).count)
        end
      end

      describe "#sum" do
        it "sums annual revenue" do
          result = Company.simple_query.sum(:annual_revenue).execute
          expected = Company.sum(:annual_revenue)
          expect(result.first.sum_annual_revenue).to eq(expected)
        end

        it "sums with custom alias" do
          result = Company.simple_query.sum(:annual_revenue, alias_name: "total_revenue").execute
          expected = Company.sum(:annual_revenue)
          expect(result.first.total_revenue).to eq(expected)
        end

        it "sums with group by" do
          result = Company.simple_query
                          .select(:industry)
                          .sum(:annual_revenue)
                          .group(:industry)
                          .execute

          expect(result.size).to be >= 1
          tech_company = result.find { |r| r.industry == "Technology" }
          expect(tech_company.sum_annual_revenue).to be_a(Numeric)
        end
      end

      describe "#avg" do
        it "calculates average annual revenue" do
          result = Company.simple_query.avg(:annual_revenue).execute
          expected = Company.average(:annual_revenue)
          expect(result.first.avg_annual_revenue.to_f).to be_within(0.01).of(expected.to_f)
        end
      end

      describe "#min and #max" do
        it "finds minimum and maximum values" do
          result = Company.simple_query
                          .min(:annual_revenue)
                          .max(:annual_revenue)
                          .execute

          expected_min = Company.minimum(:annual_revenue)
          expected_max = Company.maximum(:annual_revenue)

          expect(result.first.min_annual_revenue).to eq(expected_min)
          expect(result.first.max_annual_revenue).to eq(expected_max)
        end
      end

      describe "#custom_aggregation" do
        it "supports custom aggregation expressions" do
          result = Company.simple_query
                          .custom_aggregation("COUNT(DISTINCT industry)", "unique_industries")
                          .execute

          expect(result.first.unique_industries).to be_a(Numeric)
          expect(result.first.unique_industries).to be > 0
        end
      end

      describe "mixed select and aggregations" do
        it "combines regular selects with aggregations" do
          result = Company.simple_query
                          .select(:industry)
                          .count
                          .sum(:annual_revenue)
                          .group(:industry)
                          .execute

          expect(result.size).to be >= 1
          first_result = result.first

          expect(first_result).to respond_to(:industry)
          expect(first_result).to respond_to(:count)
          expect(first_result).to respond_to(:sum_annual_revenue)
        end

        it "works without explicit selects when using aggregations" do
          result = User.simple_query.count.execute
          expect(result.first.count).to eq(User.count)
        end
      end

      describe "with joins" do
        it "aggregates across joined tables" do
          result = User.simple_query
                       .join(:users, :companies, foreign_key: :user_id, primary_key: :id)
                       .count
                       .sum("companies.annual_revenue")
                       .execute

          expect(result.first.count).to be_a(Numeric)
          expect(result.first).to respond_to(:sum_companies_annual_revenue)
        end
      end

      describe "error handling" do
        it "raises error for sum without column" do
          expect do
            User.simple_query.sum(nil).execute
          end.to raise_error(ArgumentError, /Column is required/)
        end

        it "raises error for avg without column" do
          expect do
            User.simple_query.avg(nil).execute
          end.to raise_error(ArgumentError, /Column is required/)
        end
      end

      describe "advanced aggregation features" do
        describe "#stats" do
          it "provides comprehensive statistics for a column" do
            result = Company.simple_query.stats(:annual_revenue).execute

            expect(result.first).to respond_to(:annual_revenue_count)
            expect(result.first).to respond_to(:annual_revenue_sum)
            expect(result.first).to respond_to(:annual_revenue_avg)
            expect(result.first).to respond_to(:annual_revenue_min)
            expect(result.first).to respond_to(:annual_revenue_max)

            expect(result.first.annual_revenue_count).to eq(Company.count)
            expect(result.first.annual_revenue_sum).to eq(Company.sum(:annual_revenue))
          end

          it "accepts custom prefix" do
            result = Company.simple_query.stats(:annual_revenue, alias_prefix: "revenue").execute

            expect(result.first).to respond_to(:revenue_count)
            expect(result.first).to respond_to(:revenue_sum)
            expect(result.first).to respond_to(:revenue_avg)
            expect(result.first).to respond_to(:revenue_min)
            expect(result.first).to respond_to(:revenue_max)
          end
        end

        describe "#total_count" do
          it "counts with custom alias" do
            result = User.simple_query.total_count(alias_name: "user_total").execute
            expect(result.first.user_total).to eq(User.count)
          end

          it "uses default alias" do
            result = User.simple_query.total_count.execute
            expect(result.first.total).to eq(User.count)
          end
        end
      end
    end

    it "supports GROUP BY and HAVING" do
      result = Company.simple_query
                      .select(:industry, Arel.sql("SUM(companies.annual_revenue) AS total_revenue"))
                      .group(:industry)
                      .having(Arel.sql("SUM(companies.annual_revenue) >= 500000"))
                      .execute

      industries = result.map(&:industry)
      expect(industries).to contain_exactly("Technology", "Software")

      tech_row = result.find { |r| r.industry == "Technology" }
      soft_row = result.find { |r| r.industry == "Software" }

      expect(tech_row.total_revenue.to_i).to eq(1_000_000)
      expect(soft_row.total_revenue.to_i).to eq(500_000)
    end

    it "supports LIMIT and OFFSET" do
      all_users = User.simple_query.select(:name).execute
      limited_users = User.simple_query.select(:name).limit(1).offset(1).execute
      expect(limited_users.size).to eq(1)
      expect(limited_users.first.name).to eq(all_users[1].name)
    end

    it "supports ORDER BY clause" do
      result = User.simple_query
                   .select(:name)
                   .where(active: true)
                   .order(name: :desc)
                   .execute
      expect(result.map(&:name)).to eq(result.map(&:name).sort.reverse)
    end

    it "supports subqueries" do
      subquery = Company.simple_query
                        .select(:user_id)
                        .where(industry: "Technology")
                        .build_query
      result = User.simple_query
                   .select(:name)
                   .where(User.arel_table[:id].in(subquery))
                   .execute
      expect(result).not_to be_empty
      expect(result.first.name).to eq("Jane Doe")
    end

    it "handles complex queries with joins and multiple conditions" do
      result = User.simple_query
                   .select(:name, :email)
                   .join(:users, :companies, foreign_key: :user_id, primary_key: :id)
                   .join(:companies, :projects, foreign_key: :company_id, primary_key: :id)
                   .where(Company.arel_table[:industry].eq("Technology"))
                   .where(Project.arel_table[:status].eq("active"))
                   .where(User.arel_table[:admin].eq(true))
                   .execute

      expect(result.first).to be_an(Struct)
      expect(result.first.name).to eq("Jane Doe")
    end

    it "supports complex where clauses" do
      result = Company.simple_query
                      .where([
                               "industry = :industry AND annual_revenue <= :max_annual_revenue",
                               { industry: "Software", max_annual_revenue: 500_000 }
                             ])
                      .execute

      expect(result.size).to eq(1)
    end
  end

  describe "#lazy_execute" do
    it "supports lazy execution" do
      lazy_result = User.simple_query
                        .select(:name)
                        .where(active: true)
                        .lazy_execute
      expect(lazy_result).to be_a(Enumerator)
      expect(lazy_result.first.name).to eq("Jane Doe")
    end
  end

  describe "query caching" do
    it "caches the SQL query" do
      expect(query_object.instance_variable_get(:@query_cache)).to be_empty

      query_object.select(:name).where(active: true)
      first_sql = query_object.send(:cached_sql)

      expect(query_object.instance_variable_get(:@query_cache)).not_to be_empty
      expect(query_object.send(:cached_sql)).to eq(first_sql)
    end

    it "reuses cached SQL for identical queries" do
      query_object.select(:name).where(active: true)
      first_sql = query_object.send(:cached_sql)

      expect(query_object).not_to receive(:build_query)
      second_sql = query_object.send(:cached_sql)

      expect(second_sql).to eq(first_sql)
    end

    it "clears cache when query is modified" do
      query_object.select(:name).where(active: true)
      first_sql = query_object.send(:cached_sql)

      query_object.where(admin: false)

      expect(query_object.instance_variable_get(:@query_cache)).to be_empty
      expect(query_object.send(:cached_sql)).not_to eq(first_sql)
    end

    it "generates different cache keys for different where conditions" do
      query1 = described_class.new(User).where(active: true)
      query2 = described_class.new(User).where(admin: false)

      query1.send(:cached_sql)
      query2.send(:cached_sql)

      cache1 = query1.instance_variable_get(:@query_cache)
      cache2 = query2.instance_variable_get(:@query_cache)

      expect(cache1.keys).not_to eq(cache2.keys)
    end

    it "maintains separate caches for different query objects" do
      query1 = described_class.new(User).where(active: true)
      query2 = described_class.new(User).where(active: true)

      sql1 = query1.send(:cached_sql)
      sql2 = query2.send(:cached_sql)

      expect(sql1).to eq(sql2)
      expect(query1.instance_variable_get(:@query_cache)).not_to equal(query2.instance_variable_get(:@query_cache))
    end
  end

  describe "#map_to" do
    it "instantiates the custom read model for each row" do
      user = User.find_by(name: "Jane Doe")

      result = User.simple_query
                   .select("users.id AS id", "users.name AS name")
                   .where(name: "Jane Doe")
                   .map_to(MyUserReadModel)
                   .execute

      expect(result.size).to eq(1)
      expect(result.first).to be_a(MyUserReadModel)
      expect(result.first.identifier).to eq(user.id)
      expect(result.first.full_name).to eq("Jane Doe")
    end

    it "works with lazy_execute as well" do
      user = User.find_by(name: "John Smith")

      lazy_enum = User.simple_query
                      .select("users.id AS id", "users.name AS name")
                      .where(name: "John Smith")
                      .map_to(MyUserReadModel)
                      .lazy_execute

      record = lazy_enum.first
      expect(record).to be_a(MyUserReadModel)
      expect(record.identifier).to eq(user.id)
      expect(record.full_name).to eq("John Smith")
    end
  end

  describe "Scopes" do
    it "filters records by a parameterless scope (active)" do
      # The 'Inactive Guy' should not appear in results
      results = User.simple_query.active.execute
      expect(results.map(&:name)).to contain_exactly("Jane Doe", "John Smith")
    end

    it "filters records by another parameterless scope (admins)" do
      # Only Jane Doe is admin => see above seed data
      results = User.simple_query.admins.execute
      expect(results.map(&:name)).to eq(["Jane Doe"])
    end

    it "handles parameterized scope" do
      # We search by name using the by_name scope
      results = User.simple_query.by_name("John Smith").execute
      expect(results.map(&:name)).to eq(["John Smith"])
    end

    it "chains multiple scopes" do
      # 'Jane Doe' is both active and an admin
      # 'John Smith' is active but not an admin
      results = User.simple_query.active.admins.execute
      expect(results.map(&:name)).to eq(["Jane Doe"])
    end

    it "chains scopes with additional DSL methods" do
      # Filter by :by_name, then check if it's active, and then select
      results = User.simple_query
                    .by_name("Jane Doe")
                    .active
                    .select(:name, :admin)
                    .execute
      expect(results.size).to eq(1)
      expect(results.first.name).to eq("Jane Doe")
    end

    it "returns an empty set if scope excludes all records" do
      # We look for someone who doesn't exist
      results = User.simple_query.by_name("Nonexistent").execute
      expect(results).to be_empty
    end

    it "supports lambda scopes with complex conditions" do
      results = Company.simple_query.active.founded_after(2012).execute
      expect(results.size).to eq(1)
    end
  end

  describe "#bulk_update" do
    it "updates matching rows with the given columns" do
      query_object.where(active: true)
      query_object.bulk_update(set: { status: 9 })

      updated_count = User.where(status: 9).count
      expect(updated_count).to eq(2)
    end

    it "raises an error if the set hash includes non existing columns" do
      expect do
        query_object.bulk_update(set: { random_column: 9 })
      end.to raise_error(ActiveRecord::StatementInvalid, /random_column/)
    end

    it "raises an error if the set hash is empty" do
      expect do
        query_object.bulk_update(set: {})
      end.to raise_error(ArgumentError, /No columns to update/)
    end
  end

  describe "#stream_each" do
    context "when adapter is postgres" do
      it "calls stream_each_postgres" do
        builder = described_class.new(User)
        allow(ActiveRecord::Base.connection).to receive(:adapter_name).and_return("PostgreSQL")

        expect(builder).to receive(:stream_each_postgres).with(500).and_return(nil)
        builder.stream_each(batch_size: 500) { |row| }
      end
    end

    context "when adapter is mysql" do
      it "calls stream_each_mysql" do
        builder = described_class.new(User)
        allow(ActiveRecord::Base.connection).to receive(:adapter_name).and_return("MySQL")

        expect(builder).to receive(:stream_each_mysql).and_return(nil)
        builder.stream_each { |row| }
      end
    end

    context "when adapter is neither" do
      it "raises an error" do
        builder = described_class.new(User)
        allow(ActiveRecord::Base.connection).to receive(:adapter_name).and_return("Sqlite")

        expect { builder.stream_each }.to raise_error("stream_each is only implemented for Postgres and MySQL.")
      end
    end
  end
end
