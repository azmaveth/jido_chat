# Development Process

_This document is mainly for internal use when prompting LLMs to generate code._

Here's a comprehensive workflow for developing high-quality Elixir modules:

Pre-Development Phase:
- Define the module's primary purpose and responsibilities
- Identify potential dependencies and interactions with other modules
- Plan the public API surface and data structures
- Create corresponding struct definitions for complex data types

Implementation Phase:
1. Module Structure:
   - Start with `@moduledoc` providing comprehensive module documentation
   - Define module attributes and configuration
   - Declare custom types using `@type`, `@typep`, and `@opaque`
   - Implement structs with enforced keys using `@enforce_keys`

2. Function Implementation:
   - Write function specifications using `@spec`
   - Add detailed `@doc` tags for public functions
   - Use comments (`#`) for private function documentation
   - Implement functions with proper type handling
   - Leverage Elixir 1.18's enhanced type system features

3. Code Quality:
   - Avoid naked maps - use structs for structured data
   - Apply pattern matching for data validation
   - Implement proper error handling with tagged tuples
   - Use `Logger.warning/2` for warnings
   - Follow consistent naming conventions
   - Keep functions focused and small

Testing Phase:
1. Test File Structure:
   - Mirror lib/ structure in test/
   - Example: `lib/foo/bar.ex` → `test/foo/bar_test.exs`
   - Split large test files (>300 lines) into focused files:
     * `test/foo/bar/basic_operations_test.exs`
     * `test/foo/bar/error_handling_test.exs`
     * `test/foo/bar/integration_test.exs`

2. Test Implementation:
   - Write comprehensive doctests in function documentation
   - Implement unit tests for all public functions
   - Add integration tests for module interactions
   - Use Mimic for mocking dependencies
   - Ensure high test coverage
   - Include property-based tests for complex operations

Verification Phase:
- Run Dialyzer static analysis
- Ensure all typespecs pass
- Verify documentation completeness
- Check test coverage metrics
- Run the full test suite
- Perform code review against established standards

Deployment Phase:
- Update version number according to semantic versioning
- Generate and review documentation
- Update CHANGELOG.md
- Prepare for Hex package release
- Verify package contents with `mix hex.build`

Additional Recommendations:
- Use GitHub Actions or similar CI/CD for automated verification
- Implement credo for consistent code style
- Consider using ex_doc for documentation generation
- Add benchmarking tests for performance-critical functions
- Maintain a CONTRIBUTING.md guide for collaborators

Would you like me to elaborate on any of these points or provide specific examples for any part of the workflow?