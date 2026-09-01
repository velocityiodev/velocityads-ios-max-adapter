# AGENTS.md — velocityads-ios-max-adapter

Engineering guide for contributors and coding agents working on the Velocity Ads AppLovin MAX adapter for iOS.

---

## ⚠️ This is a public repository

This repository is publicly visible. Every file in it — `README.md`, `CHANGELOG.md`, source code comments, commit messages, and any other documentation — can be read by anyone, including publishers, competitors, and the general public.

### What must never appear in this repo

- Internal repository names (e.g. SDK internal repos, internal tooling repos).
- Internal field names, API paths, server endpoints, or request/response structures that are not part of the public SDK surface.
- Roadmap information: future mediation platforms, future adapter plans, or any unreleased product direction.
- Naming convention strategy documents or internal architecture decisions.
- Org-level CI secrets, credentials, or values (secret *names* in a prerequisites table are fine; actual values are never acceptable).
- References to internal tools, dashboards, or services not accessible to publishers.

### What belongs here

- Integration instructions written for publishers (how to add the adapter via CocoaPods / SPM, configure MAX, handle privacy).
- Adapter behaviour documentation (initialization, ad formats, error handling).
- Contributor-facing release process (how to bump versions, trigger the release workflow, required secrets).
- Public-facing `CHANGELOG.md` entries describing user-visible changes.

### Rule for coding agents

Before writing or editing any file that will be committed to this repo, ask: *could a publisher or external developer read this and learn something we did not intend to disclose?* If yes, rewrite or omit it.

---

## Project overview

This package is the official AppLovin MAX **custom-network adapter** that bridges the Velocity Ads iOS SDK (`VelocityAdsSDK`) into the MAX mediation waterfall.

- **Repository**: `velocityads-ios-max-adapter` (public)
- **Distribution**: CocoaPods trunk (`VelocityAdsMaxAdapter`) + Swift Package Manager (git tag)
- **Version scheme**: 4-segment podspec version (`<sdkMajor>.<sdkMinor>.<sdkPatch>.<adapterBuild>`); git tag is the 3-segment prefix (SPM requirement), e.g. `0.10.0`
- **Minimum iOS**: 13.0
- **Supported MAX SDK**: 13.x

---

## Module layout

```
velocityads-ios-max-adapter/
├── Sources/VelocityAdsMaxAdapter/
│   ├── AdapterVersion.swift               # Version constant: velocityAdsMaxAdapterVersion
│   ├── VelocityAdsMaxAdapter.swift        # Main adapter class (ALMediationAdapter)
│   ├── VelocityAdsMaxAdapter+Init.swift   # Initialization logic
│   ├── VelocityAdsMaxAdapter+Interstitial.swift
│   ├── VelocityAdsMaxAdapter+Rewarded.swift
│   ├── VelocityAdsMaxAdapter+Native.swift
│   └── VelocityAdsMaxAdapter+Banner.swift
├── Tests/VelocityAdsMaxAdapterTests/      # XCTest suite
├── Package.swift                          # SPM manifest
├── VelocityAdsMaxAdapter.podspec          # CocoaPods podspec
└── .github/workflows/
    ├── unit-tests.yml                     # CI: SwiftLint + xcodebuild simulator tests on PR/push
    ├── publish-adapter.yml                # Release: validate → test → pod lint → tag + GitHub Release + trunk push
    └── cocoapods-keepalive.yml            # Scheduled: keeps CocoaPods trunk token alive
```

---

## Adapter class name

The class registered in the MAX dashboard **Custom Network** entry is:

```
VelocityAdsMaxAdapter
```

Do not rename this class — it is a hard-coded string in every publisher's MAX dashboard configuration.

---

## Versioning

Version source of truth: `velocityAdsMaxAdapterVersion` in `Sources/VelocityAdsMaxAdapter/AdapterVersion.swift`.

The podspec `s.version` must always match. The git tag (used by SPM) is the 3-segment prefix — e.g. for version `0.10.0.0` the tag is `0.10.0`.

When bumping the version, update **both** `AdapterVersion.swift` and `VelocityAdsMaxAdapter.podspec` together.

---

## Build & verification

```bash
# Resolve SPM dependencies
swift package resolve

# Run unit tests (requires a connected simulator or Xcode)
xcodebuild test -scheme VelocityAdsMaxAdapter \
  -destination "platform=iOS Simulator,name=iPhone 16"

# Lint Swift code
swiftlint lint --strict

# Lint podspec (validates against live CocoaPods repos — requires network)
pod spec lint VelocityAdsMaxAdapter.podspec --allow-warnings --skip-tests
```

**SDK-first requirement**: `Package.swift` depends on the public `velocityads-ios-sdk` tag and `VelocityAdsSDK` CocoaPods pod. CI and `pod spec lint` will fail until the matching SDK version is published.

---

## CI workflows

| Workflow | Trigger | What it does |
|---|---|---|
| `unit-tests.yml` | PR / push to `main` | SwiftLint (strict) + xcodebuild simulator tests |
| `publish-adapter.yml` | Manual dispatch | Validate (versions + CHANGELOG + duplicate-tag guard) → test → pod lint → GPG tag + GitHub Release + CocoaPods trunk push |
| `cocoapods-keepalive.yml` | Every 2 days (scheduled) | Pings CocoaPods trunk to prevent token expiry |

The `env:` block at the top of each workflow file contains all adapter-specific values (scheme name, podspec name). When creating a new mediation adapter repo, copy the workflow files and update only that block.

---

## Swift conventions

Follow the conventions from the Velocity Ads iOS SDK `AGENTS.md`:

- Swift-first; no Objective-C.
- `internal` for anything not part of the public adapter surface.
- No `fatalError`, `preconditionFailure`, or `assertionFailure` in adapter code.
- No force-unwrap (`!`) in production code.
- Code must pass `swiftlint lint --strict` before merging.

---

## Changelog convention

Follow [Keep a Changelog](https://keepachangelog.com). Use `### Added`, `### Changed`, `### Fixed`, `### Breaking Changes` as section headings. Write for publishers — describe user-visible behaviour, not internal implementation.

---

## Code hygiene

Delete everything that no longer reflects the current state of the codebase:

- Dead code and unused imports.
- Stale comments or narration-only comments.
- Any reference to internal repos, tools, or field names (see the **Public repository** section above).

---

## Pre-merge checklist

1. `xcodebuild test` passes against a simulator.
2. `swiftlint lint --strict` passes with zero violations.
3. `AdapterVersion.swift` and `VelocityAdsMaxAdapter.podspec` versions match.
4. No internal repo names, field names, or roadmap content in any committed file.
5. `CHANGELOG.md` updated if the change is user-visible.
6. `README.md` updated if the public-facing integration instructions changed.
