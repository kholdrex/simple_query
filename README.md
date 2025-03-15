# SimpleQuery

SimpleQuery is a lightweight and efficient query builder for ActiveRecord, designed to provide a flexible and performant way to construct complex database queries in Ruby on Rails applications.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'simple_query'
```

And then execute:
```bash
bundle install
```

Or install it yourself as:
```bash
gem install simple_query
```

## Configuration

By default, `SimpleQuery` does **not** automatically patch `ActiveRecord::Base`. You can **manually** include the module in individual models or in a global initializer:

```ruby
# Manual include (per model)
class User < ActiveRecord::Base
  include SimpleQuery
end

# or do it globally
ActiveRecord::Base.include(SimpleQuery)
```
If you prefer a “just works” approach (i.e., every model has `.simple_query`), you can opt in:

```ruby
# config/initializers/simple_query.rb
SimpleQuery.configure do |config|
  config.auto_include_ar = true
end
```

This tells SimpleQuery to automatically do `ActiveRecord::Base.include(SimpleQuery)` for you.

## Usage

SimpleQuery offers an intuitive interface for building queries with joins, conditions, and aggregations. Here are some examples:

Basic query
```ruby
User.simple_query.select(:name, :email).where(active: true).execute
```

Query with join

SimpleQuery now supports **all major SQL join types** — including LEFT, RIGHT, and FULL — through the following DSL methods:
```ruby
User.simple_query
    .left_join(:users, :companies, foreign_key: :user_id, primary_key: :id)
    .select("users.name", "companies.name")
    .execute
```

Complex query with multiple joins and conditions
```ruby
User.simple_query
    .select(:name)
    .join(:users, :companies, foreign_key: :user_id, primary_key: :id)
    .join(:companies, :projects, foreign_key: :company_id, primary_key: :id)
    .where(Company.arel_table[:industry].eq("Technology"))
    .where(Project.arel_table[:status].eq("active"))
    .where(User.arel_table[:admin].eq(true))
    .execute
```

Lazy execution
```ruby
User.simple_query
    .select(:name)
    .where(active: true)
    .lazy_execute
```

Placeholder-Based Conditions

SimpleQuery now supports **ActiveRecord-style placeholders**, letting you pass arrays with `?` or `:named` placeholders to your `.where` clauses:

```ruby
# Positional placeholders:
User.simple_query
    .where(["name LIKE ?", "%Alice%"])
    .execute

# Named placeholders:
User.simple_query
    .where(["email = :email", { email: "alice@example.com" }])
    .execute

# Multiple placeholders in one condition:
User.simple_query
    .where(["age >= :min_age AND age <= :max_age", { min_age: 18, max_age: 35 }])
    .execute
```

## Custom Read Models
By default, SimpleQuery returns results as `Struct` objects for maximum speed. However, you can also define a lightweight model class for more explicit attribute handling or custom logic.

**Create a read model** inheriting from `SimpleQuery::ReadModel`:
```ruby
class MyUserReadModel < SimpleQuery::ReadModel
  attribute :identifier, column: :id
  attribute :full_name,  column: :name
end
```

**Map query results** to your read model:
```ruby
results = User.simple_query
              .select("users.id AS id", "users.name AS name")
              .where(active: true)
              .map_to(MyUserReadModel)
              .execute

results.each do |user|
  puts user.identifier    # => user.id from the DB
  puts user.full_name     # => user.name from the DB
end
```
This custom read model approach provides more clarity or domain-specific logic while still being faster than typical ActiveRecord instantiation.

## Named Scopes
SimpleQuery now supports named scopes, allowing you to reuse common query logic in a style similar to ActiveRecord’s built-in scopes. To define a scope, use the simple_scope class method in your model:
```ruby
class User < ActiveRecord::Base
  include SimpleQuery

  simple_scope :active do
    where(active: true)
  end

  simple_scope :admins do
    where(admin: true)
  end

  # Block-based scope with parameter
  simple_scope :by_name do |name|
    where(name: name)
  end

  # Lambda-based scope with parameter
  simple_scope :by_name, ->(name) { where(name: name) }
end
```
You can then chain these scopes seamlessly with the normal SimpleQuery DSL:

```ruby
# Parameterless scopes
results = User.simple_query.active.admins.execute

# Parameterized scope
results = User.simple_query.by_name("Jane Doe").execute

# Mixing scopes with other DSL calls
results = User.simple_query
              .by_name("John")
              .active
              .select(:id, :name)
              .order(name: :asc)
              .execute
```
### How It Works

Each scope block (e.g. by_name) is evaluated in the context of the SimpleQuery builder, so you can call any DSL method (where, order, etc.) inside it.
Parameterized scopes accept arguments — passed directly to the block (e.g. |name| above).
Scopes return self, so you can chain multiple scopes or mix them with standard query methods.

## Streaming Large Datasets

For massive queries (millions of rows), **SimpleQuery** offers a `.stream_each` method to avoid loading the entire result set into memory. It **automatically** picks a streaming approach depending on your database adapter:

- **PostgreSQL**: Uses a **server-side cursor** via `DECLARE ... FETCH`.
- **MySQL**: Uses `mysql2` gem’s **streaming** (`stream: true, cache_rows: false, as: :hash`).

```ruby
# Example usage:
User.simple_query
    .where(active: true)
    .stream_each(batch_size: 10_000) do |row|
  # row is a struct or read-model instance
  puts row.name
end
```

## Performance

SimpleQuery aims to outperform standard ActiveRecord queries at scale. We’ve benchmarked **1,000,000** records on **both PostgreSQL** and **MySQL**, with the following results:

### PostgreSQL (1,000,000 records)
```
🚀 Performance Results (1000,000 records):
ActiveRecord Query:                  10.36932 seconds
SimpleQuery Execution (Struct):      3.46136 seconds
SimpleQuery Execution (Read model):  2.20905 seconds
```
- **Struct-based** approach remains the fastest, skipping model overhead.
- **Read model** approach is still significantly faster than standard ActiveRecord while allowing domain-specific logic.

### MySQL (1,000,000 records)
```
🚀 Performance Results (1000,000 records):
ActiveRecord Query:                  10.45833 seconds
SimpleQuery Execution (Struct):      3.04655 seconds
SimpleQuery Execution (Read model):  3.69052 seconds
```
- Even in MySQL, **Struct** was roughly **three times faster** than ActiveRecord’s overhead.
- Read models still outperform AR, though by a narrower margin in this scenario.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kholdrex/simple_query. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/kholdrex/simple_query/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SimpleQuery project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/kholdrex/simple_query/blob/master/CODE_OF_CONDUCT.md).
