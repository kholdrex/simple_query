# SimpleQuery

[![Gem Version](https://badge.fury.io/rb/simple_query.svg)](https://badge.fury.io/rb/simple_query)
[![SimpleQuery CI](https://github.com/kholdrex/simple_query/actions/workflows/ci.yml/badge.svg)](https://github.com/kholdrex/simple_query/actions/workflows/ci.yml)

SimpleQuery is a lightweight query builder for ActiveRecord. It gives Rails applications an explicit, chainable API for read-heavy queries, joins, aggregations, read models, bulk updates, and adapter-aware streaming without replacing ActiveRecord.

Use it when you want ActiveRecord-backed SQL with less object-instantiation overhead, predictable result shapes, or a small query/read-model layer around reporting and data-processing code.

## Features

- Chainable query builder for ActiveRecord models
- Struct results by default for lightweight reads
- Optional custom read models with explicit attributes
- Hash, Arel, raw SQL, and ActiveRecord-style placeholder conditions
- Inner, left, right, and full joins
- `distinct`, `group`, `having`, `order`, `limit`, and `offset`
- Aggregation helpers: `count`, `sum`, `avg`, `min`, `max`, `variance`, `stddev`, `group_concat`, `stats`, and custom aggregations
- Named `simple_scope` definitions for reusable SimpleQuery chains
- `bulk_update` for set-based updates
- `stream_each` for large result sets on PostgreSQL and MySQL

## Installation

Add SimpleQuery to your application's Gemfile:

```ruby
gem "simple_query"
```

Then install:

```bash
bundle install
```

Or install it directly:

```bash
gem install simple_query
```

## Compatibility

SimpleQuery currently declares support for:

- Ruby `>= 2.7`
- ActiveRecord `>= 7.0`, `< 8.1`

The CI matrix covers ActiveRecord 7.0, 7.1, 7.2, and 8.0 across PostgreSQL and MySQL. ActiveRecord 7.0 is covered through Ruby 3.2; ActiveRecord 8.0 requires Ruby 3.2 or newer; otherwise each Ruby is exercised on the ActiveRecord versions that support it.

## Configuration

SimpleQuery does not patch every ActiveRecord model by default. Include it in the models that should expose `.simple_query`:

```ruby
class User < ActiveRecord::Base
  include SimpleQuery
end
```

Or include it globally if you want every ActiveRecord model to have `.simple_query`:

```ruby
# config/initializers/simple_query.rb
require "simple_query"

ActiveRecord::Base.include(SimpleQuery)
```

You can also opt into global inclusion through SimpleQuery's configuration hook:

```ruby
# config/initializers/simple_query.rb
SimpleQuery.configure do |config|
  config.auto_include_ar = true
end
```

## Basic usage

```ruby
users = User.simple_query
            .select(:name, :email)
            .where(active: true)
            .order(name: :asc)
            .limit(50)
            .execute

users.first
# => #<struct name="Jane Doe", email="jane@example.com">
```

`execute` returns an array of lightweight `Struct` objects unless you map the query to a custom read model.

## Conditions

SimpleQuery accepts several condition styles.

### Hash conditions

```ruby
User.simple_query
    .select(:name, :email)
    .where(active: true, admin: false)
    .execute
```

Hash conditions are simple equality predicates against the query's base table.

### Arel conditions

```ruby
users = User.arel_table

User.simple_query
    .select(:name)
    .where(users[:created_at].gteq(30.days.ago))
    .execute
```

### Placeholder conditions

Array conditions are sanitized through ActiveRecord's `sanitize_sql_array`, so they are the preferred way to use SQL fragments with external or user-provided values:

```ruby
escaped_search = ActiveRecord::Base.sanitize_sql_like(params[:search].to_s)
search_pattern = "%#{escaped_search}%"

User.simple_query
    .where(["name LIKE ?", search_pattern])
    .execute

User.simple_query
    .where(["email = :email", { email: params[:email] }])
    .execute
```

Keep the SQL fragment itself static and pass dynamic values as positional or named placeholders so ActiveRecord quotes them as SQL data literals. Do not interpolate request parameters, form values, or other untrusted input into the SQL string.

### Raw SQL conditions

Plain strings are treated as raw SQL fragments:

```ruby
User.simple_query
    .where("active = TRUE")
    .execute
```

Raw SQL strings are an escape hatch for trusted, application-owned SQL only. If any value comes from a user, request, file, or external service, use hash, Arel, or placeholder conditions instead. The checklist below shows the safer patterns to prefer when query inputs are dynamic.

### SQL fragment safety checklist

SimpleQuery intentionally accepts SQL fragments in places where ActiveRecord also leaves judgment to the application, such as raw `where` strings, string `select` values, and `custom_aggregation` expressions. Treat those fragments as trusted code, not as a templating surface for request data.

Prefer these patterns for dynamic values:

```ruby
# Good: read dynamic values, then pass them separately so ActiveRecord quotes them.
email = params.fetch(:email)
User.simple_query
    .where(["email = :email", { email: email }])
    .execute

# Good: quote LIKE values with placeholders. Escape wildcard characters when
# `%` and `_` should be treated as literal search text instead of wildcards.
search = params.fetch(:search)
escaped_search = ActiveRecord::Base.sanitize_sql_like(search)
User.simple_query
    .where(["name LIKE ?", "%#{escaped_search}%"])
    .execute
```

Avoid interpolating untrusted values into SQL fragments:

```ruby
# Unsafe: request data is interpolated into a raw SQL string.
User.simple_query
    .where("email = '#{params[:email]}'")
    .execute
```

Even with quotes around the value, interpolation is unsafe because an apostrophe or SQL fragment in the input can break out of the literal. Keep the SQL string static and pass values through placeholders so ActiveRecord quotes them as SQL data literals instead. For `LIKE` queries, `sanitize_sql_like` only changes matching semantics by escaping `%`, `_`, and the escape character itself; it is useful when those characters should be searched literally, but it does not replace placeholder quoting.

The same boundary applies outside `where`: keep selected expressions, ordering fragments, and custom aggregation SQL static and application-owned. When a user chooses a column, sort direction, or metric, map that input to a small allowlist before building the query:

```ruby
sort_columns = {
  "name" => :name,
  "created_at" => :created_at
}
sort_directions = {
  "asc" => :asc,
  "desc" => :desc
}

User.simple_query
    .select(:id, :name, :email)
    .order(sort_columns.fetch(params[:sort], :name) => sort_directions.fetch(params[:direction], :asc))
    .execute
```

## Joins

Joins are explicit: pass the left table, right table, foreign key, and primary key.

```ruby
User.simple_query
    .select(:name, :email)
    .join(:users, :companies, foreign_key: :user_id, primary_key: :id)
    .where(Company.arel_table[:name].eq("TechCorp"))
    .execute
```

Multiple joins can be chained:

```ruby
User.simple_query
    .select(:name)
    .join(:users, :companies, foreign_key: :user_id, primary_key: :id)
    .join(:companies, :projects, foreign_key: :company_id, primary_key: :id)
    .where(Company.arel_table[:industry].eq("Technology"))
    .where(Project.arel_table[:status].eq("active"))
    .execute
```

Join helpers are also available:

```ruby
User.simple_query
    .left_join(:users, :companies, foreign_key: :user_id, primary_key: :id)
    .select(:name)
    .execute
```

Supported join types:

- `join(..., type: :inner)` / `join(...)`
- `left_join(...)`
- `right_join(...)`
- `full_join(...)`

Database support for right and full outer joins depends on the adapter and database version.

## Selecting, ordering, and paging

```ruby
User.simple_query
    .select(:id, :name, "LOWER(email) AS normalized_email")
    .distinct
    .where(active: true)
    .order(name: :asc)
    .limit(25)
    .offset(50)
    .execute
```

`select` accepts symbols, SQL strings, and Arel nodes. SQL strings are inserted as SQL fragments, so keep them trusted.

`order` accepts a hash of column names to directions, such as `order(created_at: :desc)`.

## Aggregations

SimpleQuery can build common aggregate expressions without hand-writing each SQL expression.

```ruby
Company.simple_query
       .count
       .sum(:annual_revenue)
       .avg(:annual_revenue)
       .min(:annual_revenue)
       .max(:annual_revenue)
       .execute
```

Custom aliases are supported:

```ruby
Company.simple_query
       .count(:id, alias_name: "company_count")
       .sum(:annual_revenue, alias_name: "total_revenue")
       .execute
```

Grouped aggregations work with selected fields:

```ruby
Company.simple_query
       .select(:industry)
       .count(alias_name: "company_count")
       .sum(:annual_revenue, alias_name: "total_revenue")
       .group(:industry)
       .execute
```

Convenience helpers include:

```ruby
Company.simple_query.stats(:annual_revenue).execute
Company.simple_query.total_count.execute
User.simple_query.variance(:score).stddev(:score).execute
User.simple_query.group_concat(:name, separator: ", ").execute
```

For database-specific expressions, use `custom_aggregation` with trusted SQL:

```ruby
Company.simple_query
       .custom_aggregation("COUNT(DISTINCT industry)", "unique_industries")
       .execute
```

## Custom read models

By default, query results are returned as `Struct` objects. For named methods and domain-specific result objects, define a read model:

```ruby
class UserSummary < SimpleQuery::ReadModel
  attribute :identifier, column: :id
  attribute :full_name, column: :name
end
```

Map query results to the read model:

```ruby
users = User.simple_query
            .select("users.id AS id", "users.name AS name")
            .where(active: true)
            .map_to(UserSummary)
            .execute

users.first.identifier
users.first.full_name
```

The selected SQL aliases must match the read model's configured column names.

## Named scopes

Use `simple_scope` to define reusable query fragments on a model that includes SimpleQuery:

```ruby
class User < ActiveRecord::Base
  include SimpleQuery

  simple_scope :active do
    where(active: true)
  end

  simple_scope :admins, -> { where(admin: true) }

  simple_scope :by_name do |name|
    where(name: name)
  end
end
```

Scopes are evaluated in the context of the SimpleQuery builder and can be chained with the normal DSL:

```ruby
User.simple_query
    .active
    .admins
    .by_name("Jane Doe")
    .select(:id, :name)
    .execute
```

SimpleQuery validates positional scope arguments before invoking the scope body. If a scope is called with too few or too many positional arguments, it raises `ArgumentError` with the scope name and expected argument count. For scopes that declare Ruby keyword parameters, SimpleQuery forwards keywords to the scope body and lets Ruby raise its native keyword-argument errors.

## Lazy execution and streaming

`lazy_execute` returns an `Enumerator` over the query results:

```ruby
enumerator = User.simple_query
                 .select(:name)
                 .where(active: true)
                 .lazy_execute

enumerator.each do |user|
  puts user.name
end
```

`lazy_execute` is useful when you want enumerator-style consumption, but it still uses ActiveRecord's `select_all` internally.

For large PostgreSQL or MySQL result sets, use `stream_each`:

```ruby
User.simple_query
    .select(:id, :email)
    .where(active: true)
    .stream_each(batch_size: 10_000) do |user|
  puts user.email
end
```

Adapter behavior:

- PostgreSQL: uses a server-side cursor with `DECLARE` / `FETCH`; `batch_size` must be a positive integer and controls the number of rows fetched per cursor read
- MySQL: uses `mysql2` streaming with `stream: true`, `cache_rows: false`, and `as: :hash`; `batch_size` is validated as a positive integer for API symmetry, but mysql2 streams rows directly and does not expose a SimpleQuery-controlled batch size
- Other adapters: `stream_each` raises `SimpleQuery::UnsupportedAdapterError` with the current adapter name

Failure behavior:

- `batch_size` must be a positive integer; invalid values raise `ArgumentError` before any adapter-specific SQL runs
- PostgreSQL streaming wraps the cursor in a transaction, closes a declared cursor before rollback when row processing fails, attempts cursor cleanup before rollback on fetch failures, and propagates the original error
- MySQL streaming uses the mysql2 driver's streaming result handling; query and row processing errors are propagated to the caller

## Bulk updates

`bulk_update` builds and executes a set-based `UPDATE` for the current query conditions:

```ruby
User.simple_query
    .where(active: false)
    .bulk_update(set: { status: 0 })
```

`bulk_update` sends SQL directly through the ActiveRecord connection and does not instantiate models or run ActiveRecord callbacks. If no `where` conditions are present, it updates the entire table.

## Subqueries

You can use `build_query` to embed a SimpleQuery query as an Arel subquery:

```ruby
company_users = Company.simple_query
                       .select(:user_id)
                       .where(industry: "Technology")
                       .build_query

User.simple_query
    .select(:name)
    .where(User.arel_table[:id].in(company_users))
    .execute
```

## Performance

SimpleQuery is designed for read paths where ActiveRecord model instantiation is unnecessary overhead. Returning structs or read models can reduce allocation costs for large reporting-style queries.

The repository includes an optional benchmark harness comparing ActiveRecord object loading and `update_all` with SimpleQuery structs, read models, and `bulk_update`. Treat benchmark numbers as workload-specific: validate them against your database, indexes, adapter, Ruby version, and query shape before making production claims.

Run the reproducible local benchmark with:

```sh
bundle exec rake benchmark:reproducible
```

The harness uses SQLite by default, seeds deterministic data, warms up and repeats each timing measurement, and prints JSON with environment metadata plus timing results. If `memory_profiler` is available in your development bundle, the JSON also includes single-run allocation profiles for the read-path scenarios. Tune the workload with environment variables:

```sh
BENCHMARK_ROWS=50000 BENCHMARK_WARMUP=3 BENCHMARK_RUNS=10 \
  bundle exec rake benchmark:reproducible
```

Available variables:

- `BENCHMARK_ROWS` (default: `10000`) controls the number of users and matching companies seeded.
- `BENCHMARK_WARMUP` (default: `2`) controls warmup iterations before samples are collected.
- `BENCHMARK_RUNS` (default: `5`) controls the number of timed samples per scenario.
- `BENCHMARK_DATABASE` (default: `:memory:`) can point at a SQLite database file if you want to inspect the generated benchmark-specific tables. The harness drops and recreates `simple_query_benchmark_users` and `simple_query_benchmark_companies` in that database on every run.

Use captured benchmark output only as a reproducibility artifact. Do not compare runs from different hardware, databases, Ruby versions, or dependency sets as if they were equivalent.

## Safety notes

SimpleQuery is a query-building library, not an authorization or SQL-injection protection layer. It exposes both parameterized condition helpers and raw SQL escape hatches; choose the narrowest API that fits the value source.

Recommended usage:

- Prefer hash, Arel, or placeholder conditions for values derived from users or external systems.
- Treat raw SQL strings in `select`, `where`, and `custom_aggregation` as trusted-only escape hatches.
- Keep `group_concat` separators static and trusted; they are interpolated into database-specific SQL.
- Use Arel nodes or `Arel.sql(...)` for `having` clauses; it does not share the same condition parser as `where`.
- Keep tenant, authorization, and visibility constraints explicit in your query code.
- Remember that `bulk_update` bypasses model callbacks and validations, like any direct SQL update.

### Parameterized values

Use hash conditions for simple equality predicates and array placeholder conditions for SQL fragments that include external values:

```ruby
# Equality predicates are built through Arel.
User.simple_query.where(email: params[:email]).execute

# SQL fragments with external values should use ActiveRecord-style placeholders.
query = params[:query].to_s
escaped_query = ActiveRecord::Base.sanitize_sql_like(query)

User.simple_query
    .where(["name ILIKE ?", "%#{escaped_query}%"])
    .execute

User.simple_query
    .where(["email = :email", { email: params[:email] }])
    .execute
```

Placeholders quote values as SQL data literals, while `sanitize_sql_like` makes `%` and `_` match literally in `LIKE` patterns; escaping the pattern does not replace placeholder quoting.

Do not interpolate external values into raw strings:

```ruby
# Unsafe: params[:query] is part of the SQL string itself.
User.simple_query.where("name ILIKE '%#{params[:query]}%'").execute
```

### Trusted SQL escape hatches

Some APIs intentionally accept SQL fragments because they are meant for expressions that Arel or SimpleQuery helpers do not model:

```ruby
# Trusted expression: fixed by the application, not assembled from request input.
User.simple_query.select("LOWER(email) AS normalized_email").execute

Company.simple_query
       .custom_aggregation("COUNT(DISTINCT industry)", "unique_industries")
       .execute
```

Keep aliases, custom aggregation expressions, raw `select` strings, raw `where` strings, `having` expressions, and `group_concat` separators static or otherwise trusted. If a condition must include external values, express those values with hash, Arel, or placeholder `where` syntax instead of interpolating them into raw SQL fragments.

### Direct updates

`bulk_update` is a set-based SQL update. It is useful for maintenance jobs and data workflows where callbacks are intentionally skipped, but it will not run ActiveRecord validations, callbacks, authorization checks, or per-record business logic. Always add the intended `where` conditions before calling it unless the whole table is the target.

## Development

After checking out the repository:

```bash
bin/setup
bundle exec rspec
bundle exec rubocop
```

Database-sensitive behavior is tested against PostgreSQL and MySQL in CI.

You can also open a console:

```bash
bin/console
```

## Contributing

Bug reports and pull requests are welcome on GitHub at [kholdrex/simple_query](https://github.com/kholdrex/simple_query). Contributors are expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## Code of Conduct

Everyone interacting in the SimpleQuery project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
