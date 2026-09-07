# Releasing

Maintainer runbook for publishing a new adapter version. Publishers do not need
anything on this page — see [README.md](README.md) for integration instructions.

## Before you start

- The matching Velocity Ads SDK version must already be available on both
  CocoaPods trunk (`VelocityAdsSDK`) and as a Swift Package tag; `pod lib lint`
  and the SPM build fail until it is.
- The version follows the 4-segment MAX convention
  `<sdkMajor>.<sdkMinor>.<sdkPatch>.<adapterBuild>` (e.g. `0.10.0.0`).

## Steps

1. Create a branch named `release/<version>` (e.g. `release/0.10.0.0`).
2. Bump `velocityAdsMaxAdapterVersion` in `Sources/VelocityAdsMaxAdapter/AdapterVersion.swift`
   and `s.version` in `VelocityAdsMaxAdapter.podspec` — they must match.
3. Add a `## [<version>] - YYYY-MM-DD` entry at the top of `CHANGELOG.md`.
4. Push the branch and open a PR to `main`.
5. In **Actions → Publish Adapter**, click **Run workflow** with the release branch
   selected, enter the version, and set **Dry run** to `true`. The workflow refuses
   to run from any branch other than `release/<version>`.
6. A dry run validates versions, runs the tests, and lints the podspec without
   tagging or pushing to trunk.
7. Re-run the workflow with **Dry run** set to `false`. The tag-and-release job
   waits for approval from the `production-release` GitHub Environment.
8. Merge the release PR.

## What a release produces

- Two GPG-signed git tags: the 4-segment tag (e.g. `0.10.0.0`) used by CocoaPods,
  and the encoded SPM tag (e.g. `100000.0.0` — each segment zero-padded to two
  digits and concatenated) used by Swift Package Manager.
- A GitHub Release on the 4-segment tag with the CHANGELOG entry and install snippets.
- The podspec pushed to CocoaPods trunk.

## Secrets

The workflow's *Validate required secrets* step fails early and names any secret
that is missing. Configure them under **Settings → Secrets and variables →
Actions**:

| Secret | Used for |
|---|---|
| `GPG_PRIVATE_KEY`, `GPG_PASSPHRASE`, `GPG_SIGNING_KEY_ID`, `GPG_TAGGER_NAME`, `GPG_TAGGER_EMAIL` | Signing the release git tags |
| `COCOAPODS_TRUNK_TOKEN` | Pushing the podspec to CocoaPods trunk (kept alive by `cocoapods-keepalive.yml`) |
