# frozen_string_literal: true

require "active_record"
require "benchmark"
require "bundler"
require "json"
require "open3"
require "simple_query"
require "simple_query/version"

begin
  require "memory_profiler"
rescue LoadError
  nil
end

module SimpleQueryBenchmark # rubocop:disable Metrics/ModuleLength
  DEFAULT_ROWS = 10_000
  DEFAULT_RUNS = 5
  DEFAULT_WARMUP = 2
  USERS_TABLE = :simple_query_benchmark_users
  COMPANIES_TABLE = :simple_query_benchmark_companies
  STATUSES = [0, 1, 2].freeze
  INDUSTRIES = ["Technology", "Finance", "Healthcare", "Education"].freeze

  module_function

  def run
    config = benchmark_config
    setup_database(config)
    seed_data(config.fetch(:rows))

    results = {
      metadata: metadata(config),
      timings: timing_results(config),
      memory: memory_results
    }

    puts JSON.pretty_generate(results)
  end

  def benchmark_config
    {
      rows: integer_env("BENCHMARK_ROWS", DEFAULT_ROWS),
      runs: integer_env("BENCHMARK_RUNS", DEFAULT_RUNS),
      warmup: integer_env("BENCHMARK_WARMUP", DEFAULT_WARMUP),
      database: ENV.fetch("BENCHMARK_DATABASE", ":memory:")
    }
  end

  def integer_env(name, default)
    value = begin
      Integer(ENV.fetch(name, default).to_s, 10)
    rescue ArgumentError
      raise ArgumentError, "#{name} must be a positive integer"
    end

    raise ArgumentError, "#{name} must be positive" unless value.positive?

    value
  end

  def setup_database(config)
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: config.fetch(:database))
    ActiveRecord::Migration.verbose = false

    ActiveRecord::Schema.define do
      drop_table COMPANIES_TABLE, if_exists: true
      drop_table USERS_TABLE, if_exists: true

      create_table USERS_TABLE do |t|
        t.string :name
        t.string :email
        t.boolean :active
        t.integer :status
      end

      create_table COMPANIES_TABLE do |t|
        t.string :name
        t.integer :user_id
        t.string :industry
        t.boolean :active
        t.integer :status
      end
    end

    ActiveRecord::Base.include(SimpleQuery)
  end

  def seed_data(rows)
    users = Array.new(rows) do |index|
      {
        name: "User #{index}",
        email: "user-#{index}@example.test",
        active: index.even?,
        status: STATUSES[index % STATUSES.length]
      }
    end

    User.insert_all!(users)

    user_ids = User.order(:id).pluck(:id)
    companies = user_ids.each_with_index.map do |user_id, index|
      {
        name: "Company #{index}",
        user_id: user_id,
        industry: INDUSTRIES[index % INDUSTRIES.length],
        active: index.even?,
        status: STATUSES[index % STATUSES.length]
      }
    end

    Company.insert_all!(companies)
  end

  def metadata(config)
    {
      ruby: RUBY_DESCRIPTION,
      ruby_platform: RUBY_PLATFORM,
      bundler: Bundler::VERSION,
      active_record: ActiveRecord::VERSION::STRING,
      simple_query: SimpleQuery::VERSION,
      adapter: ActiveRecord::Base.connection.adapter_name,
      git_revision: git_revision,
      git_dirty: git_dirty,
      benchmark_environment: benchmark_environment,
      rows: config.fetch(:rows),
      runs: config.fetch(:runs),
      warmup: config.fetch(:warmup),
      database: config.fetch(:database)
    }
  end

  def git_revision
    git_output("rev-parse", "HEAD")
  end

  def git_dirty
    status = git_output("status", "--porcelain")
    return nil if status.nil?

    !status.empty?
  end

  def git_output(*arguments)
    stdout, _stderr, status = Open3.capture3("git", *arguments, chdir: project_root)
    return nil unless status.success?

    stdout.strip
  rescue Errno::ENOENT
    nil
  end

  def project_root
    File.expand_path("..", __dir__)
  end

  def benchmark_environment
    ENV.select { |key, _value| key.start_with?("BENCHMARK_") }
       .sort_by { |key, _value| key }
       .to_h
  end

  def timing_results(config)
    {
      active_record_objects: measure(config) { active_record_objects },
      simple_query_structs: measure(config) { simple_query_structs },
      simple_query_read_models: measure(config) { simple_query_read_models },
      active_record_update_all: measure_update(config) { active_record_update_all },
      simple_query_bulk_update: measure_update(config) { simple_query_bulk_update }
    }
  end

  def measure(config, &block)
    config.fetch(:warmup).times(&block)

    samples = Array.new(config.fetch(:runs)) do
      Benchmark.realtime(&block)
    end

    summarize_samples(samples)
  end

  def measure_update(config, &block)
    config.fetch(:warmup).times do
      reset_update_rows
      block.call
    end

    samples = Array.new(config.fetch(:runs)) do
      reset_update_rows
      Benchmark.realtime(&block)
    end

    summarize_samples(samples)
  end

  def summarize_samples(samples)
    {
      samples_seconds: samples.map { |sample| sample.round(6) },
      min_seconds: samples.min.round(6),
      average_seconds: (samples.sum / samples.length).round(6)
    }
  end

  def active_record_objects
    ActiveRecord::Base.uncached do
      User.joins(:company)
          .where(User.table_name => { active: true })
          .select("#{User.table_name}.id", "#{User.table_name}.name")
          .to_a
    end
  end

  def simple_query_structs
    ActiveRecord::Base.uncached do
      User.simple_query
          .select(:id, :name)
          .join(USERS_TABLE, COMPANIES_TABLE, foreign_key: :user_id, primary_key: :id)
          .where(active: true)
          .execute
    end
  end

  def simple_query_read_models
    ActiveRecord::Base.uncached do
      User.simple_query
          .select(:id, :name)
          .join(USERS_TABLE, COMPANIES_TABLE, foreign_key: :user_id, primary_key: :id)
          .where(active: true)
          .map_to(UserReadModel)
          .execute
    end
  end

  def active_record_update_all
    User.where(active: false).update_all(status: 1)
  end

  def simple_query_bulk_update
    User.simple_query.where(active: false).bulk_update(set: { status: 1 })
  end

  def reset_update_rows
    User.where(active: false).update_all(status: 0)
  end

  def memory_results
    return { available: false, reason: "memory_profiler unavailable" } unless defined?(MemoryProfiler)

    {
      available: true,
      profiles: {
        active_record_objects: memory_profile { active_record_objects },
        simple_query_structs: memory_profile { simple_query_structs },
        simple_query_read_models: memory_profile { simple_query_read_models }
      }
    }
  end

  def memory_profile(&block)
    report = MemoryProfiler.report(&block)

    {
      total_allocated: report.total_allocated,
      total_allocated_memsize: report.total_allocated_memsize
    }
  end

  class User < ActiveRecord::Base
    self.table_name = USERS_TABLE.to_s
    has_one :company, class_name: "SimpleQueryBenchmark::Company"
  end

  class Company < ActiveRecord::Base
    self.table_name = COMPANIES_TABLE.to_s
    belongs_to :user, class_name: "SimpleQueryBenchmark::User"
  end

  class UserReadModel < SimpleQuery::ReadModel
    attribute :id
    attribute :name
  end
end

SimpleQueryBenchmark.run if $PROGRAM_NAME == __FILE__
