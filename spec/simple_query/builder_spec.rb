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
  end

  describe "Performance Test" do
    before do
      puts "\n⚡ Inserting 100,000 test records for benchmarking..."
      users = []
      companies = []

      100_000.times do |i|
        users << {
          name: "User#{i}",
          email: "user#{i}@example.com",
          first_name: "First#{i}",
          last_name: "Last#{i}",
          active: true,
          admin: i % 100 == 0,
          status: i % 3
        }
      end

      User.insert_all(users)

      users = User.pluck(:id)
      users.each_with_index do |user_id, i|
        companies << {
          name: "Company#{i}",
          user_id: user_id,
          registration_number: "REG#{i}",
          founded_year: 2000 + (i % 25),
          industry: ["Tech", "Finance", "Healthcare", "Education"].sample,
          active: true,
          size: i % 3,
          status: i % 3,
          annual_revenue: rand(100_000..10_000_000)
        }
      end

      Company.insert_all(companies)
      puts "✅ Data Inserted!"
    end

    it "compares ActiveRecord vs SimpleQuery performance on a larger dataset" do
      ar_time = Benchmark.realtime do
        ActiveRecord::Base.uncached do
          User.joins(:companies).where(active: true).to_a
        end
      end

      simple_query_struct_time = Benchmark.realtime do
        ActiveRecord::Base.uncached do
          User.simple_query
              .select(:name, :id)
              .join(:users, :companies, foreign_key: :user_id, primary_key: :id)
              .where(active: true).execute
        end
      end

      simple_query_read_model_time = Benchmark.realtime do
        ActiveRecord::Base.uncached do
          User.simple_query
              .select(:name, :id)
              .join(:users, :companies, foreign_key: :user_id, primary_key: :id)
              .where(active: true)
              .map_to(MyUserReadModel)
              .execute
        end
      end

      puts "\n🚀 Performance Results (100,000 records):"
      puts "ActiveRecord Query:                  #{ar_time.round(5)} seconds"
      puts "SimpleQuery Execution (Struct):      #{simple_query_struct_time.round(5)} seconds"
      puts "SimpleQuery Execution (Read model):  #{simple_query_read_model_time.round(5)} seconds"

      expect(simple_query_struct_time).to be < ar_time
    end
  end
end
