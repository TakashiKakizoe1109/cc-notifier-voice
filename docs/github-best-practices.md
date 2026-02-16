# GitHub Best Practices Checklist

Status legend: [x] done / [ ] todo

---

## High Priority

### CI/CD (GitHub Actions)

- [x] `.github/workflows/ci.yml` -- ShellCheck lint + `bash -n` syntax check + Bats test execution on push/PR
- [ ] `.github/workflows/release.yml` -- auto-create GitHub Release on tag push (extract CHANGELOG section as body)
- [x] `.shellcheckrc` -- ShellCheck configuration for project-wide rules

### SECURITY.md

- [x] Vulnerability reporting policy (contact method, response SLA, scope)
- [x] Supported versions table
- [x] Disclosure process

---

## Medium Priority

### CONTRIBUTING.md

- [x] Development environment setup
- [x] How to run tests (`bats tests/`)
- [x] How to run lint (`shellcheck plugin/scripts/**/*.sh`)
- [x] PR process and review expectations
- [x] Commit message conventions (Conventional Commits)
- [x] Version update checklist reference (see CLAUDE.md)

### Issue / PR Templates

- [x] `.github/ISSUE_TEMPLATE/bug_report.yml` -- OS, version, reproduction steps, expected/actual behavior
- [x] `.github/ISSUE_TEMPLATE/feature_request.yml` -- use case, proposed solution, alternatives considered
- [x] `.github/ISSUE_TEMPLATE/config.yml` -- template chooser configuration
- [x] `.github/PULL_REQUEST_TEMPLATE.md` -- summary, test plan, checklist (bash -n, shellcheck, docs sync)

### .gitattributes

- [ ] Line ending normalization (`* text=auto`)
- [ ] Binary file markers (`*.app binary`, `*.aiff binary`)
- [ ] Export-ignore for dev-only files (`export-ignore` on tests/, .agent/, .claude/)

### CODEOWNERS

- [ ] `.github/CODEOWNERS` -- assign reviewers per path (e.g., `plugin/scripts/lib/ @maintainer`)

---

## Low Priority

### CODE_OF_CONDUCT.md

- [ ] Adopt Contributor Covenant or equivalent
- [ ] Link from CONTRIBUTING.md

### .editorconfig

- [ ] Indent style/size for shell scripts, markdown, JSON, YAML
- [ ] Trim trailing whitespace, insert final newline
- [ ] Charset utf-8

### FUNDING.yml

- [ ] `.github/FUNDING.yml` -- GitHub Sponsors or other platforms

### Dependabot

- [ ] `.github/dependabot.yml` -- auto-update GitHub Actions action versions

### GitHub Repository Settings (manual)

- [ ] Repository description and topics (`claude-code`, `notification`, `tts`, `macos`, `wsl2`)
- [ ] Branch protection on `main`: require PR, require review, require CI status check, block force push
- [ ] Enable "Automatically delete head branches" after PR merge

---

## Reference: CI Workflow Sketch

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: ShellCheck
        uses: ludeeus/action-shellcheck@2.0.0
        with:
          scandir: plugin/scripts
      - name: Bash syntax check
        run: |
          for f in $(find plugin/scripts -name '*.sh'); do
            bash -n "$f"
          done

  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: bats tests/
```

## Reference: Release Workflow Sketch

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - name: Extract changelog
        id: changelog
        run: |
          VERSION="${GITHUB_REF_NAME#v}"
          awk "/^## \[${VERSION}\]/{flag=1; next} /^## \[/{flag=0} flag" CHANGELOG.md > release_notes.md
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          body_path: release_notes.md
```

## Reference: .gitattributes

```
* text=auto
*.sh text eol=lf
*.md text eol=lf
*.json text eol=lf
*.yml text eol=lf
*.yaml text eol=lf
*.aiff binary
*.mp3 binary
*.app binary

# Exclude from release archives
.agent/ export-ignore
.claude/ export-ignore
.github/ export-ignore
tests/ export-ignore
docs/ export-ignore
CLAUDE.md export-ignore
CODEX.md export-ignore
```

## Reference: .editorconfig

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.sh]
indent_style = space
indent_size = 2

[*.md]
indent_style = space
indent_size = 2
trim_trailing_whitespace = false

[*.{json,yml,yaml}]
indent_style = space
indent_size = 2

[Makefile]
indent_style = tab
```
