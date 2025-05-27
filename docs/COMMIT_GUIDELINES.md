# Git Commit Message Guidelines

This document outlines the commit message standards for the OHdio Audiobook Downloader project. We follow the Angular commit convention with emojis for better visual organization and readability.

## Format

```
<emoji> <type>(<scope>): <subject>

<body>

<footer>
```

## Structure

### Header Line (Required)
The header consists of three parts: **emoji**, **type**, **scope** (optional), and **subject**.

#### Emojis by Type
- ✨ `feat` - New features
- 🐛 `fix` - Bug fixes
- 📚 `docs` - Documentation changes
- 💄 `style` - Code style changes (formatting, missing semicolons, etc.)
- ♻️ `refactor` - Code refactoring (no functional changes)
- ⚡ `perf` - Performance improvements
- ✅ `test` - Adding or modifying tests
- 🔧 `build` - Build system or external dependencies
- 👷 `ci` - CI/CD configuration changes
- 🔨 `chore` - Maintenance tasks
- ⏪ `revert` - Reverting previous commits
- 🚀 `deploy` - Deployment related changes
- 🔒 `security` - Security improvements
- 🌐 `i18n` - Internationalization changes
- ♿ `a11y` - Accessibility improvements
- 💬 `config` - Configuration changes

#### Types
- **feat**: A new feature for the user
- **fix**: A bug fix for the user
- **docs**: Changes to documentation
- **style**: Formatting, missing semicolons, etc; no code change
- **refactor**: Refactoring production code
- **perf**: Performance improvements
- **test**: Adding tests, refactoring test; no production code change
- **build**: Changes to build process or auxiliary tools
- **ci**: Changes to CI configuration files and scripts
- **chore**: Updating grunt tasks etc; no production code change
- **revert**: Reverting a previous commit
- **deploy**: Deployment related changes
- **security**: Security related changes
- **config**: Configuration file changes

#### Scope (Optional)
The scope provides additional contextual information and is contained within parentheses:
- **scraper**: Changes to web scraping components
- **downloader**: Changes to download functionality
- **metadata**: Changes to metadata management
- **config**: Changes to configuration system
- **logger**: Changes to logging functionality
- **utils**: Changes to utility functions
- **test**: Changes to test files
- **docs**: Changes to documentation
- **cli**: Changes to command-line interface
- **deps**: Changes to dependencies

#### Subject
- Use imperative mood: "add" not "added" or "adds"
- Don't capitalize first letter
- No period (.) at the end
- Maximum 50 characters

### Body (Optional)
- Use imperative mood
- Explain what and why, not how
- Wrap at 72 characters
- Separate from header with blank line

### Footer (Optional)
- Reference issues and breaking changes
- Format: `Closes #123` or `Fixes #456`
- Breaking changes start with `BREAKING CHANGE:`

## Examples

### Basic Examples

```
✨ feat(scraper): add playlist URL extraction from media API

🐛 fix(downloader): handle connection timeout errors gracefully

📚 docs: update README with testing instructions

♻️ refactor(config): simplify configuration loading logic

✅ test(metadata): add tests for artwork embedding

🔧 build: update dependencies to latest versions
```

### With Body and Footer

```
✨ feat(scraper): implement category page audiobook discovery

Add comprehensive scraping logic for OHdio category pages:
- Support multiple parsing strategies for resilience
- Extract title, author, URL, and thumbnail information
- Handle pagination and dynamic content loading
- Add retry logic with exponential backoff

The scraper can now discover 125+ audiobooks from the 
Jeunesse category page with 98% success rate.

Closes #15
```

```
🐛 fix(downloader): resolve memory leak in concurrent downloads

Fix issue where download tasks were not properly cleaned up
after completion, causing memory usage to grow over time
during bulk downloads.

- Implement proper task cleanup in semaphore context
- Add memory monitoring utilities
- Update concurrent processing logic

Fixes #23
```

### Breaking Changes

```
💥 feat(config): redesign configuration system

BREAKING CHANGE: Configuration file format has changed from
JSON to TOML. Update your config.json to config.toml format.

Migration guide:
- Rename config.json to config.toml
- Update syntax: "key": "value" becomes key = "value"
- Arrays: ["a", "b"] becomes ["a", "b"] (unchanged)

Closes #45
```

### Special Cases

```
🔒 security(auth): implement rate limiting for API requests

⚡ perf(downloader): optimize concurrent download performance

🌐 i18n: add French language support for error messages

♿ a11y(cli): improve command-line accessibility

⏪ revert: "feat(scraper): add experimental parsing method"

This reverts commit abc123def456 due to stability issues.

🚀 deploy: configure production environment settings

👷 ci: add automated testing workflow for pull requests
```

## Best Practices

### Do ✅
- Keep the subject line under 50 characters
- Use the imperative mood ("add" not "added")
- Choose the most specific scope possible
- Include issue references in the footer
- Explain the "why" in the body, not the "how"
- Use present tense for the subject

### Don't ❌
- Don't end the subject line with a period
- Don't capitalize the first letter of the subject
- Don't be vague ("fix stuff", "update code")
- Don't commit unrelated changes together
- Don't use past tense ("added", "fixed")

## Scope Guidelines

Choose the most specific scope that applies:

- **scraper**: `category_scraper.py`, `audiobook_scraper.py`, `playlist_extractor.py`
- **downloader**: `ytdlp_downloader.py`, `metadata_manager.py`
- **utils**: `config.py`, `logger.py`, `file_utils.py`, `network_utils.py`
- **test**: Any files in test directories or test-related changes
- **docs**: Documentation files (`.md`, docstrings)
- **cli**: `main.py`, command-line argument parsing
- **config**: `config.json`, `pyproject.toml`
- **deps**: Dependency updates, requirement changes

## Tools and Automation

### Git Hooks
Consider setting up git hooks to validate commit messages:

```bash
# .git/hooks/commit-msg
#!/bin/sh
commit_regex='^(✨|🐛|📚|💄|♻️|⚡|✅|🔧|👷|🔨|⏪|🚀|🔒|🌐|♿|💬) (feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|deploy|security|config)(\(.+\))?: .{1,50}'

if ! grep -qE "$commit_regex" "$1"; then
    echo "Invalid commit message format!"
    echo "Please follow the guidelines in docs/COMMIT_GUIDELINES.md"
    exit 1
fi
```

### IDE Integration
Most IDEs support commit message templates. Create `.gitmessage` in your project root:

```
# <emoji> <type>(<scope>): <subject>
# 
# <body>
# 
# <footer>
```

## Reference

This standard is based on:
- [Angular Commit Message Guidelines](https://github.com/angular/angular/blob/master/CONTRIBUTING.md#-commit-message-guidelines)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Gitmoji](https://gitmoji.dev/) for emoji standards

For questions about these guidelines, please refer to the project maintainers or create an issue. 