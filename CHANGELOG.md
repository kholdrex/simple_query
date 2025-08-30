# Changelog

All notable changes to this project are documented in this file.

## [0.5.0] - 2025-01-XX

### Added
- **Enhanced Aggregation Support**: Comprehensive aggregation methods for improved developer experience
  - Basic aggregations: `count`, `sum`, `avg`, `min`, `max`
  - Statistical functions: `variance`, `stddev`
  - Database-specific functions: `group_concat` (MySQL/PostgreSQL/SQLite compatible)
  - Advanced features: `stats` method for comprehensive column statistics
  - Custom aggregations via `custom_aggregation` method
  - All aggregation methods support custom aliases
  - Automatic alias sanitization for complex column names (e.g., `companies.revenue` → `companies_revenue`)
- **Aggregation DSL**: Fluent interface for chaining aggregations with other query methods
- **Comprehensive Test Coverage**: Full test suite for aggregation functionality
- **Enhanced Documentation**: Detailed aggregation guide with examples

### Changed
- **Query Building**: Updated builder to seamlessly integrate aggregations with SELECT clauses
- **SQL Generation**: Improved handling of mixed regular selects and aggregations
- **Type Definitions**: Updated RBS signatures to include new aggregation methods

### Performance
- **Database-Level Aggregations**: All calculations performed at the database level for optimal performance
- **Memory Efficiency**: Aggregations use minimal memory compared to loading full record sets

## [0.4.0] - 2025-03-17

### Added
- **MySQL Streaming**: `stream_each` now supports MySQL (via `mysql2` gem’s streaming mode) in addition to PostgreSQL cursors.
- **Multi-DB Performance**: Officially tested and benchmarked on both Postgres and MySQL, showing significant speed and memory savings vs. ActiveRecord.
- **Memory Profiling**: Documented memory usage comparisons, demonstrating up to ~50% fewer allocations in `stream_each` vs `find_each`.
- **Enhanced Bulk Update**: Additional benchmarks for `.bulk_update` show 10–25% faster updates than `update_all` in large datasets.
- **Improved README**: Updated Performance section with streaming benchmarks, memory usage stats, and multi-DB coverage.

### Changed
- **Refactored** streaming logic into separate modules (`PostgresStream`, `MysqlStream`) for cleaner DB-specific code.
- **Loosen** tests for quoting, ensuring MySQL’s backticks and Postgres’s double quotes both pass with minimal overhead.

## [0.3.2] - 2025-02-28

### Added
- **Extended Join Types**
  - Introduced `.left_join`, `.right_join`, and `.full_join` DSL methods, each calling the existing `.join(..., type: ...)` under the hood.
  - Fallback logic for older Arel versions that do not define `RightOuterJoin`, `FullOuterJoin`. In those cases, SimpleQuery uses either a raw approach or reverts to `INNER JOIN` (for Right/Full).
- **Improved DSL Consistency**
  - Users can now specify more precise join behaviors (LEFT OUTER, RIGHT OUTER, FULL OUTER) without manual `type: :left` arguments.

### Notes
- This version remains backward-compatible with previous 0.3.x versions.
- Database / Arel support for `RIGHT` or `FULL` join may be limited in MySQL < 8.x or older frameworks. SimpleQuery will gracefully fallback to `INNER JOIN` if the underlying Arel node is undefined.

---

## [0.3.1] - 2025-02-26

### Added
- **Placeholder-Based Conditions**
  - Introduced support for **ActiveRecord-style** placeholders in `.where`:
    ```ruby
      where(["email = ?", "test@example.com"])
      where(["name LIKE :name", { name: "%Bob%" }])
    ```
  - Internally uses `sanitize_sql_array` for safe SQL quoting.
  - New RSpec tests verify both **positional** (`?`) and **named** (`:name`) placeholders.

### Notes
- This is a **minor** update to `0.3.0`, preserving backwards compatibility.
- See the README’s “Placeholder-Based Conditions” section for usage examples.

---

## [0.3.0] - 2025-02-25

### Added
- **Named Scopes Support**
    - Introduced a `simple_scope` class method to define **parameterless** or **parameterized** scopes directly in your models.
    - Updated `Builder` to recognize scope calls via `method_missing`, enabling scope chaining (e.g., `User.simple_query.active.admins`) similar to ActiveRecord scopes.
    - Provided new RSpec tests confirming parameterless, parameterized, and chained scopes.

### Notes
- This release is **backward-compatible** with 0.2.x, requiring no changes to existing queries. Users can optionally adopt scopes for cleaner, reusable query logic.

---

## [0.2.0] - 2025-02-21

### Added
- **Modular Clause Classes**: Extracted query-building logic for WHERE, JOIN, ORDER, DISTINCT, LIMIT/OFFSET, and GROUP/HAVING into dedicated classes. This refactoring improves maintainability and testability.
- **Optimized Custom Read Models**: Implemented array-based row processing to greatly reduce per-row overhead. This enhancement allows custom read models to approach Struct-level performance on large datasets.
- **Configuration Option for Auto-Inclusion**: Introduced a configuration system that lets users opt in to automatically include `SimpleQuery` into `ActiveRecord::Base`. By default, auto-inclusion is disabled, so users can choose to include it manually if desired.
- **CI Matrix Enhancements**: Updated GitHub Actions workflow to test across multiple Ruby versions and ActiveRecord versions using multiple Gemfiles. Exclusions have been added for unsupported Ruby/ActiveRecord combinations to ensure a stable CI build.

### Changed
- **Builder Refactoring**: The `SimpleQuery::Builder` class has been refactored to delegate clause handling to the new modular clause classes and use optimized instantiation for read models.
- **Test Suite**: Expanded test coverage with dedicated specs for each clause class (WHERE, JOIN, ORDER, DISTINCT, LIMIT/OFFSET, GROUP/HAVING) as well as integration tests in the builder.

### Fixed
- **Compatibility Issues**: Resolved issues with ActiveRecord by excluding problematic combinations in the CI matrix and adjusting migration/table creation code for older ActiveRecord versions.

---

**Note**: If you’re upgrading from `0.2.x` to `0.3.0`, simply `bundle update simple_query` (or update your Gemfile) and enjoy the new named scopes feature while retaining all existing functionality. For more details, see the [README](./README.md) or the updated documentation sections on named scopes.
