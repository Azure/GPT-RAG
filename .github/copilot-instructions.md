# Repository Development and Release Instructions

## Overview

This repository follows a structured workflow based on two primary branches:

- `develop` → ongoing development
- `main` → stable, released versions

All work must follow the branching, versioning, and changelog rules defined below.

---

## Branching Strategy

### Default Behavior

Unless explicitly instructed otherwise:

- All development work MUST start from `develop`
- All new work MUST be done in a feature branch
- Feature work MUST target `develop`
- Release preparation MUST target `main`

---

## Feature Development Workflow

### Branch Creation

- Always create feature branches from `develop`
- Naming convention:
  - `feature/<short-description>`

Examples:
- `feature/conversation-metadata`
- `feature/improve-chat-history`

---

### Feature Pull Requests

- Source branch: `feature/*`
- Target branch: `develop`
- Never target `main` from a feature branch

---

### Expected Flow

1. Start from `develop`
2. Create `feature/<name>`
3. Implement changes
4. Commit changes
5. Open pull request to `develop`

---

## Release Workflow

### Release Branch Creation

- Release branches MUST be created from `develop`
- Naming convention:
  - `release/x.y.z` (no `v` prefix)

Examples:
- `release/1.2.3`
- `release/2.4.2`

---

### Release Responsibilities

When preparing a release branch:

- Update version references where applicable
- Update `CHANGELOG.md`
- Ensure the repository reflects a releasable state
- Do NOT introduce new feature work

---

### Release Pull Requests

- Source branch: `release/x.y.z`
- Target branch: `main`

---

### Expected Flow

1. Start from `develop`
2. Create `release/x.y.z`
3. Update version and changelog
4. Open pull request to `main`

---

## Versioning Rules

- Follow semantic versioning: `MAJOR.MINOR.PATCH`
- Version numbers MUST use the `v` prefix in:
  - tags
  - changelog entries

Examples:
- `v1.2.3`
- `v2.4.2`

---

### Important Distinction

- Branch name:
  - `release/1.2.3`
- Tag and changelog:
  - `v1.2.3`

---

### Version Increment Guidelines

- PATCH → bug fixes and minor improvements
- MINOR → backward-compatible features
- MAJOR → breaking changes

---

## Changelog Rules

### Format

- Follow **Keep a Changelog**
- Follow **Semantic Versioning**
- Every release MUST update `CHANGELOG.md`

---

### Version Header Format

```md
## [vX.Y.Z] - YYYY-MM-DD