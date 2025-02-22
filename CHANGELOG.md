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
