# Changelog

All notable changes to this project are documented in this file.

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
