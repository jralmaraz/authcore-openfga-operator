# Contributing to OpenFGA Operator

Thank you for your interest in contributing to the OpenFGA Operator! This document provides guidelines for contributing to this project.

## Code Organization and Separation Policy

### Core Operator Source Code Separation

**IMPORTANT**: The OpenFGA operator source code (`src/` directory) must **NEVER** be mixed with demo or other application source code. This is a strict repository policy to ensure:

- Clean architectural boundaries
- Maintainable operator core functionality  
- Clear separation of concerns
- Simplified testing and deployment

### Prohibited Practices

The following practices are **strictly prohibited**:

1. **Including demo modules in `src/main.rs`** or any other operator source files
2. **Adding demo application code** to the `src/` directory
3. **Using `include!()` macros** to embed demo code into the operator binary
4. **Mixing demo dependencies** with core operator dependencies in `Cargo.toml`
5. **Adding demo-specific imports or references** in operator source code

### Correct Project Structure

```
authcore-openfga-operator/
├── src/                    # Core operator source code ONLY
│   ├── main.rs            # Operator entry point (NO demo includes)
│   ├── controller.rs      # Kubernetes controller logic
│   └── types.rs           # CRD and type definitions
├── demos/                 # Demo applications (SEPARATE)
│   ├── banking-app/       # Banking demo (standalone)
│   ├── genai-rag/         # GenAI RAG demo (standalone)
│   └── README.md          # Demo documentation
├── tests/                 # Core operator tests
└── CONTRIBUTING.md        # This file
```

### Demo Development Guidelines

Demo applications should be:

1. **Self-contained** within the `demos/` directory
2. **Independently testable** without operator integration
3. **Documented** with their own README files
4. **Deployable** as standalone applications
5. **Example-focused** for educational purposes

### How to Add New Demos

When creating new demo applications:

1. Create a new subdirectory under `demos/`
2. Include a comprehensive README with setup instructions
3. Provide OpenFGA authorization models as separate files
4. Implement realistic test scenarios
5. Ensure the demo can run independently
6. **Never** include demo code in the operator source (`src/`)

### Core Operator Development

When working on the operator core:

1. Keep all operator logic in the `src/` directory
2. Focus on Kubernetes controller functionality
3. Ensure tests validate operator behavior only
4. Maintain clean separation from demo code
5. Document operator-specific features in the main README

## Code Quality Standards

### Testing

- Core operator tests should be in `tests/` or `src/` with `#[cfg(test)]`
- Demo tests should be within their respective demo directories
- All tests should be focused and validate specific functionality
- Avoid mixing demo test logic with operator test logic

### Documentation

- Update relevant README files for any changes
- Include inline documentation for complex functions
- Maintain clear API documentation
- Keep demo documentation separate from operator documentation

### Code Style

- Follow standard Rust formatting with `cargo fmt`
- Use meaningful variable and function names
- Keep functions focused on single responsibilities
- Add comments for complex business logic

## Pull Request Guidelines

1. **Describe your changes** clearly in the PR description
2. **Follow the separation policy** outlined above
3. **Include tests** for new functionality
4. **Update documentation** as needed
5. **Ensure all checks pass** before requesting review

### PR Checklist

- [ ] Changes maintain clean separation between operator and demo code
- [ ] No demo code included in `src/` directory
- [ ] Tests pass and cover new functionality
- [ ] Documentation updated (README, inline docs)
- [ ] Code follows Rust best practices
- [ ] Commit messages are clear and descriptive

## Enforcement

Violations of the separation policy will result in:

1. **Immediate PR rejection** for mixing operator and demo code
2. **Required refactoring** to maintain proper separation
3. **Code review focus** on architectural boundaries

This policy ensures the OpenFGA operator remains maintainable, testable, and professionally architected.

## Getting Help

If you have questions about:

- **Operator functionality**: Check the main [README.md](README.md)
- **Demo applications**: See [demos/README.md](demos/README.md) and [DEMOS.md](DEMOS.md)
- **Contributing process**: Open an issue for clarification
- **Separation policy**: Refer to this document or ask in discussions

Thank you for helping maintain the quality and architecture of the OpenFGA Operator!