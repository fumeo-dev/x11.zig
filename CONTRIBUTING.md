# Contributing

Thanks for your interest in contributing to x11.zig.

## Before You Start

### Project Direction

x11.zig aims to provide a robust, well-documented, Zig-native client library with broad coverage of practically useful X11 functionality.

The project values:

- **Zig-native design:** APIs should feel natural and idiomatic in Zig.
- **Direct access to X11 concepts:** Preserve X11 concepts and functionality rather than unnecessarily hiding them.
- **Careful abstraction:** Provide abstractions where they improve usability without unnecessarily restricting flexibility.
- **Robustness and maintainability:** Prioritize correctness and designs that can scale with the project.
- **High-effort documentation:** Public APIs and non-obvious behavior should be clearly explained.

x11.zig is not intended to be a high-level GUI toolkit or a thin wrapper around an existing X11 library.

Contributions should fit the project's scope, direction, and long-term design.

### Requirements

- Linux
- The Zig version currently supported by the project

> [!NOTE]
> x11.zig generally tracks the latest Zig release. Because Zig is still pre-1.0 and evolves rapidly, support for older versions may be dropped when the project moves to a newer release.

### Setup

If you do not have write access to the repository, fork the repository on GitHub and clone your fork.

Otherwise, clone the repository directly:

```sh
git clone https://github.com/fumeo-dev/x11.zig.git
cd x11.zig
```

Verify your setup:

```sh
zig build test
```

## Development

### Testing

Run the test suite with:

```sh
zig build test
```

Run relevant tests while developing and before opening a pull request.

Add or update tests when a contribution introduces or changes behavior, when practical.

### Formatting

Format the repository with:

```sh
zig fmt .
```

All code must be formatted before it can be merged. Formatting is checked automatically by continuous integration.

### Code Quality

Contributions should prioritize:

- **Correctness**
- **Clarity**
- **Maintainability**
- **Consistency**
- **Idiomatic Zig design**

Prefer simple designs that fit naturally within the surrounding code.

Introduce abstractions when they provide a clear benefit without unnecessarily reducing flexibility.

### Documentation

Documentation is part of the project.

Document public APIs and behavior that would otherwise be unclear. Explain important X11-specific semantics and non-obvious design decisions when doing so improves understanding and maintainability.

Prioritize accuracy and clarity.

### Code Organization

Organize code around clear concepts and responsibilities.

A primary module may be accompanied by a matching directory containing related implementation details:

```text
src/
├── Display.zig
└── Display/
    └── Parser.zig
```

Prefer simple organization. Add files and directories when they improve clarity, maintainability, or separation of responsibilities.

Avoid splitting code purely to follow a pattern.

### Dependencies

Avoid introducing dependencies unless they provide a clear benefit that justifies their complexity and maintenance cost.

Discuss significant dependency additions before implementation.

## Contributing Changes

### Issues

Issues are useful for reporting bugs, proposing changes, and discussing ideas.

#### Changes That Can Usually Go Straight to a Pull Request

Small and straightforward changes usually do not need prior discussion.

Examples include:

- Typographical fixes
- Small documentation improvements
- Straightforward bug fixes
- Small, self-contained improvements

#### Changes That Should Usually Be Discussed First

Open an issue before investing significant implementation effort when a change involves:

- Significant API changes
- Architectural changes
- Major functionality
- New or significant abstractions
- Significant dependencies

Early discussion helps ensure that the proposed approach fits the project and avoids duplicated or unnecessary work.

If you're unsure whether a change needs prior discussion, open an issue first.

If you plan to work on a substantial existing issue, leave a comment first to let others know. This helps avoid duplicated effort but does not permanently reserve the issue.

### Branches and Commits

Keep branches and commits focused on one logical change.

The project generally uses the following change types:

| Type       | Purpose                | Branch         | Commit          |
| ---------- | ---------------------- | -------------- | --------------- |
| `feat`     | New functionality      | `feat/...`     | `feat: ...`     |
| `fix`      | Bug fixes              | `fix/...`      | `fix: ...`      |
| `docs`     | Documentation          | `docs/...`     | `docs: ...`     |
| `refactor` | Internal restructuring | `refactor/...` | `refactor: ...` |
| `test`     | Tests                  | `test/...`     | `test: ...`     |
| `ci`       | Continuous integration | `ci/...`       | `ci: ...`       |
| `build`    | Build configuration    | `build/...`    | `build: ...`    |
| `chore`    | General maintenance    | `chore/...`    | `chore: ...`    |

Use a short, lowercase kebab-case description for branch names:

```text
feat/connection
fix/display-parser
docs/contributing-guide
```

Commit messages generally follow Conventional Commit-style formatting:

```text
feat: add connection support
fix: handle invalid display strings
docs: add contributing guide
```

Scopes may be used when they improve clarity:

```text
feat(connection): add Unix socket support
```

Keep descriptions clear and avoid mixing unrelated changes in the same branch or commit when practical.

## Pull Requests

### Before Opening a Pull Request

Use a clear title and keep the pull request focused on a single purpose.

Provide enough context for reviewers to understand what changed and why. Link relevant issues when applicable.

Before opening a pull request:

- [ ] Code is formatted.
- [ ] Relevant tests pass.
- [ ] Tests are added or updated when appropriate.
- [ ] Documentation is updated when necessary.

If a change grows significantly beyond its original scope, consider splitting it into smaller logical pull requests.

Required continuous integration (CI) checks must pass before a pull request can be merged.

### Review and Acceptance

Pull requests are reviewed for:

- Correctness and code quality
- Maintainability and consistency
- API and abstraction design
- Appropriate tests and documentation
- Alignment with the project's direction

Review feedback may require changes before a pull request is accepted.

Passing CI means that the automated checks succeeded. It does not automatically mean that a pull request will be merged.

A contribution may still require changes or be declined if it does not fit the project's scope, direction, or long-term design.

## Code of Conduct

By participating in x11.zig, you agree to follow the project's [Code of Conduct](CODE_OF_CONDUCT.md).

## Security

Do not report security vulnerabilities through public issues or pull requests.

See [SECURITY.md](SECURITY.md) for information about reporting vulnerabilities.
