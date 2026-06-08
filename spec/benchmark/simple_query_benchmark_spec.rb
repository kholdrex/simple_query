# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "stringio"

RSpec.describe "benchmark/simple_query_benchmark" do
  def benchmark_path
    File.expand_path("../../benchmark/simple_query_benchmark.rb", __dir__)
  end

  def with_benchmark_env(values)
    previous = ENV.select { |key, _value| key.start_with?("BENCHMARK_") }

    ENV.delete_if { |key, _value| key.start_with?("BENCHMARK_") }
    values.each { |key, value| ENV[key] = value }

    yield
  ensure
    ENV.delete_if { |key, _value| key.start_with?("BENCHMARK_") }
    previous.each { |key, value| ENV[key] = value }
  end

  def valid_integer_env
    {
      "BENCHMARK_ROWS" => "1",
      "BENCHMARK_RUNS" => "1",
      "BENCHMARK_WARMUP" => "1"
    }
  end

  def subprocess_env(env)
    ENV.to_h.reject { |key, _value| key.start_with?("BENCHMARK_") }.merge(env)
  end

  def capture_ruby(*arguments, env: {})
    Open3.popen3(
      subprocess_env(env),
      RbConfig.ruby,
      "-rbundler/setup",
      *arguments,
      chdir: File.expand_path("../..", __dir__)
    ) do |stdin, stdout, stderr, wait_thread|
      stdin.close
      stdout_reader = Thread.new { stdout.read }
      stderr_reader = Thread.new { stderr.read }

      wait_for_subprocess(wait_thread, stdout_reader, stderr_reader)

      [stdout_reader.value, stderr_reader.value, wait_thread.value]
    end
  end

  def wait_for_subprocess(wait_thread, stdout_reader, stderr_reader)
    return if wait_thread.join(60)

    terminate_process(wait_thread.pid, "TERM")
    unless wait_thread.join(5)
      terminate_process(wait_thread.pid, "KILL")
      wait_thread.join
    end

    stdout = stdout_reader.value
    stderr = stderr_reader.value
    raise "Ruby subprocess timed out after 60 seconds\n#{status_diagnostics(stdout, stderr)}"
  end

  def status_diagnostics(stdout, stderr)
    "stdout:\n#{stdout}\nstderr:\n#{stderr}"
  end

  def terminate_process(pid, signal)
    Process.kill(signal, pid)
  rescue Errno::ESRCH
    nil
  end

  describe "requiring the harness" do
    it "does not run the benchmark implicitly" do
      stdout, stderr, status = capture_ruby(
        "-Ilib",
        "-e",
        "require './benchmark/simple_query_benchmark'; puts 'loaded'",
        env: { "BENCHMARK_ROWS" => "1", "BENCHMARK_RUNS" => "1", "BENCHMARK_WARMUP" => "1" }
      )

      expect(status).to be_success, status_diagnostics(stdout, stderr)
      expect(stdout).to include("loaded\n")
      expect(stdout).not_to include('"metadata"')
      expect(stdout).not_to include('"timings"')
    end
  end

  describe ".benchmark_config" do
    before do
      require benchmark_path
    end

    it "reads benchmark environment values and coerces positive integers" do
      with_benchmark_env(
        "BENCHMARK_ROWS" => "12",
        "BENCHMARK_RUNS" => "3",
        "BENCHMARK_WARMUP" => "2",
        "BENCHMARK_DATABASE" => "tmp/benchmark.sqlite3"
      ) do
        expect(SimpleQueryBenchmark.benchmark_config).to eq(
          rows: 12,
          runs: 3,
          warmup: 2,
          database: "tmp/benchmark.sqlite3"
        )
      end
    end

    it "raises a useful error for invalid integer environment values" do
      aggregate_failures do
        ["BENCHMARK_ROWS", "BENCHMARK_RUNS", "BENCHMARK_WARMUP"].each do |key|
          with_benchmark_env(valid_integer_env.merge(key => "not-a-number")) do
            expect { SimpleQueryBenchmark.benchmark_config }
              .to raise_error(ArgumentError, "#{key} must be a positive integer")
          end
        end
      end
    end

    it "raises a useful error for non-positive integer environment values" do
      aggregate_failures do
        ["BENCHMARK_ROWS", "BENCHMARK_RUNS", "BENCHMARK_WARMUP"].each do |key|
          with_benchmark_env(valid_integer_env.merge(key => "0")) do
            expect { SimpleQueryBenchmark.benchmark_config }
              .to raise_error(ArgumentError, "#{key} must be positive")
          end
        end
      end
    end
  end

  describe ".metadata" do
    before do
      require benchmark_path
    end

    it "includes repository, runtime, and benchmark environment details" do
      allow(SimpleQueryBenchmark).to receive(:git_revision).and_return("abc123")
      allow(SimpleQueryBenchmark).to receive(:git_dirty).and_return(false)

      with_benchmark_env(
        "BENCHMARK_ROWS" => "12",
        "BENCHMARK_RUNS" => "3",
        "BENCHMARK_WARMUP" => "2",
        "BENCHMARK_DATABASE" => "tmp/benchmark.sqlite3"
      ) do
        metadata = SimpleQueryBenchmark.metadata(
          rows: 12,
          runs: 3,
          warmup: 2,
          database: "tmp/benchmark.sqlite3"
        )

        expect(metadata).to include(
          ruby: RUBY_DESCRIPTION,
          ruby_platform: RUBY_PLATFORM,
          bundler: Bundler::VERSION,
          active_record: ActiveRecord::VERSION::STRING,
          simple_query: SimpleQuery::VERSION,
          adapter: ActiveRecord::Base.connection.adapter_name,
          git_revision: "abc123",
          git_dirty: false,
          rows: 12,
          runs: 3,
          warmup: 2,
          database: "tmp/benchmark.sqlite3"
        )
        expect(metadata.fetch(:benchmark_environment)).to eq(
          "BENCHMARK_DATABASE" => "tmp/benchmark.sqlite3",
          "BENCHMARK_ROWS" => "12",
          "BENCHMARK_RUNS" => "3",
          "BENCHMARK_WARMUP" => "2"
        )
      end
    end

    it "returns nil git values when repository metadata is unavailable" do
      allow(SimpleQueryBenchmark).to receive(:git_output).and_return(nil)

      expect(SimpleQueryBenchmark.git_revision).to be_nil
      expect(SimpleQueryBenchmark.git_dirty).to be_nil
    end

    it "returns nil when the git executable is unavailable" do
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

      expect(SimpleQueryBenchmark.git_output("rev-parse", "HEAD")).to be_nil
    end

    it "returns nil when git cannot be executed" do
      allow(Open3).to receive(:capture3).and_raise(Errno::EACCES)

      expect(SimpleQueryBenchmark.git_output("rev-parse", "HEAD")).to be_nil
    end
  end

  describe "running the harness" do
    it "emits parseable JSON with metadata, timings, memory, and config values" do
      require benchmark_path

      with_benchmark_env(
        "BENCHMARK_ROWS" => "2",
        "BENCHMARK_RUNS" => "1",
        "BENCHMARK_WARMUP" => "1",
        "BENCHMARK_DATABASE" => "benchmark-test.sqlite3"
      ) do
        previous_stdout = $stdout
        allow(SimpleQueryBenchmark).to receive(:setup_database)
        allow(SimpleQueryBenchmark).to receive(:seed_data)
        allow(SimpleQueryBenchmark).to receive(:metadata).and_return(
          ruby: RUBY_DESCRIPTION,
          active_record: ActiveRecord::VERSION::STRING,
          simple_query: SimpleQuery::VERSION,
          adapter: "SQLite",
          rows: 2,
          runs: 1,
          warmup: 1,
          database: "benchmark-test.sqlite3"
        )
        allow(SimpleQueryBenchmark).to receive(:timing_results).and_return(
          active_record_objects: {
            samples_seconds: [0.001],
            min_seconds: 0.001,
            average_seconds: 0.001
          },
          simple_query_structs: { samples_seconds: [0.001], min_seconds: 0.001, average_seconds: 0.001 },
          simple_query_read_models: { samples_seconds: [0.001], min_seconds: 0.001, average_seconds: 0.001 },
          active_record_update_all: { samples_seconds: [0.001], min_seconds: 0.001, average_seconds: 0.001 },
          simple_query_bulk_update: { samples_seconds: [0.001], min_seconds: 0.001, average_seconds: 0.001 }
        )
        allow(SimpleQueryBenchmark).to receive(:memory_results).and_return(available: false)

        stdout = StringIO.new
        $stdout = stdout
        SimpleQueryBenchmark.run
        $stdout = previous_stdout

        parsed = JSON.parse(stdout.string)
        expect(parsed.keys).to include("metadata", "timings", "memory")

        metadata = parsed.fetch("metadata")
        expect(metadata).to include(
          "ruby",
          "active_record",
          "simple_query",
          "adapter"
        )
        expect(metadata).to include(
          "rows" => 2,
          "runs" => 1,
          "warmup" => 1,
          "database" => "benchmark-test.sqlite3"
        )

        expect(parsed.fetch("timings")).to include(
          "active_record_objects",
          "simple_query_structs",
          "simple_query_read_models",
          "active_record_update_all",
          "simple_query_bulk_update"
        )
        expect(parsed.fetch("timings").fetch("active_record_objects"))
          .to include("samples_seconds", "min_seconds", "average_seconds")
        expect(parsed.fetch("memory")).to include("available")
      ensure
        $stdout = previous_stdout
      end
    end
  end
end
