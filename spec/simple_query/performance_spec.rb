# frozen_string_literal: true

require "benchmark"

RSpec.describe SimpleQuery::Builder do
  let(:query_object) { described_class.new(User) }

  describe "Performance Test" do
    before(:all) do
      puts "\n⚡ Inserting 1000,000 test records for benchmarking..."
      users = []
      companies = []

      1_000_000.times do |i|
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

      puts "\n🚀 Performance Results (1000,000 records):"
      puts "ActiveRecord Query:                  #{ar_time.round(5)} seconds"
      puts "SimpleQuery Execution (Struct):      #{simple_query_struct_time.round(5)} seconds"
      puts "SimpleQuery Execution (Read model):  #{simple_query_read_model_time.round(5)} seconds"

      expect(simple_query_struct_time).to be < ar_time
    end

    it "compares update_all vs bulk_update on a large dataset" do
      ar_time = Benchmark.realtime do
        User.where(active: false).update_all(status: 1)
      end

      User.where(active: false).update_all(status: nil)

      sq_time = Benchmark.realtime do
        builder = SimpleQuery::Builder.new(User)
        builder.where(active: false).bulk_update(set: { status: 2 })
      end

      puts "\n--- Bulk Update Benchmark ---"
      puts "ActiveRecord update_all: #{ar_time.round(5)} seconds"
      puts "SimpleQuery bulk_update: #{sq_time.round(5)} seconds"

      rows_updated_ar = User.where(status: 2).count
      rows_updated_sq = User.where(status: 2).count
      expect(rows_updated_ar).to eq(rows_updated_sq)
    end
  end
end
