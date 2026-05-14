# Changelog

## [1.1.2](https://github.com/sendbird/sendbird-auth-ios/releases/tag/1.1.2) (May 14, 2026)
### Added
- `SendbirdLogger` — public, central log-level controller shared across all Sendbird iOS SDKs (Chat, UIKit, AI Agent, Desk).
- `SendbirdLogger.setLevel(_:)` — sets a global default level.
- `SendbirdLogger.setLevel(_:for:)` / `SendbirdLogger.level(for:)` — per-product overrides keyed by `ProductIdentifier` (`.chat`, `.uikit`, `.aiagent`, `.desk`).
- `AuthLogLevel` and `ProductIdentifier` are now public.
- Unified log format across SDKs: `<timestamp> [<level>] [<product>/<category>] <File>.swift:<line> - <message>`.

### Changed
- Default log level is `.none`. Apps that previously relied on implicit logging must now opt in via `SendbirdLogger.setLevel(...)`.
- Once `SendbirdLogger.setLevel(...)` is called, any subsequent legacy per-SDK setter (`SendbirdChat.setLogLevel`, `SendbirdUI.setLogLevel`, `SBDSKMain.setSBDSKLogLevel`,
`AIAgentMessenger.InitializeParams.logLevel`) becomes a no-op. Mixing the two APIs is safe; the new API always wins.

## [1.1.1](https://github.com/sendbird/sendbird-auth-ios/releases/tag/1.1.1) (Apr 24, 2026)
### Changes
- Add `sort(by:)` method to `SafeOrderedDictionary` (thread-safe, `@_spi(SendbirdInternal)`) (#139)
- Add `/test check` workflow and PR template with SDK Branch Override section (#136)
- Fix `/test check` workflow to mirror all chat sub-statuses (#137)

## [1.1.0](https://github.com/sendbird/sendbird-auth-ios/releases/tag/1.1.0) (Apr 09, 2026)
### Build Environment

- Rebuilt with **Xcode 26** to comply with Apple's App Store submission requirement,
  effective late April 2026, which mandates that all apps be built using Xcode 26 or later.
- No functional changes or API modifications are included in this release.

> **Note for Xcode 16 users:** This release is compiled with Xcode 26 and may not be
> compatible with Xcode 16 build environments. If you are still on Xcode 16, please
> continue using the previous version.

## [1.0.2](https://github.com/sendbird/sendbird-auth-ios/releases/tag/1.0.2) (Apr 08, 2026)
### Improvements

- Built with Xcode 26 to comply with Apple's latest SDK requirements

## [1.0.1](https://github.com/sendbird/sendbird-auth-ios/releases/tag/1.0.1) (Mar 26, 2026)
### New Features

- Multiple instance support
- Add `loadHostFromAppGroup` method for NotificationExtension (#100)

### Improvements

- Internal improvements

## [1.0.0](https://github.com/sendbird/sendbird-auth-ios/releases/tag/1.0.0) (Mar 18, 2026)
### New Features

- Multiple instance support

### Improvements

- Internal improvements

## [0.0.12](https://github.com/sendbird/sendbird-auth-ios/releases/tag/0.0.12) (Mar 10, 2026)
### Changes
- Internal improvements only

## [0.0.11](https://github.com/sendbird/sendbird-auth-ios/releases/tag/0.0.11) (Feb 20, 2026)
### Changes
- Add bundle injection (#91)

## [0.0.10](https://github.com/sendbird/sendbird-auth-ios/releases/tag/0.0.10) (Feb 11, 2026)
### Features
- Added auth SDK info to version string

### Improvements
- Improved stability

## [0.0.10](https://github.com/sendbird/sendbird-auth-ios/releases/tag/0.0.10) (Feb 11, 2026)
### Features
- Added auth SDK info to version string

### Improvements
- Improved stability

## [0.0.9](https://github.com/sendbird/sendbird-auth-ios/releases/tag/0.0.9) (Jan 29, 2026)
### Improvements

- Support extendable URL path and code key

### Bug fixes

- Fix updating user crash
