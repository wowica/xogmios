# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- Add manual syncing mechanism for ChainSync. This adds an optional back-pressure when building chain indexers that rely on Xogmios. Tested with GenStage on [the following experimental branch](https://github.com/wowica/xogmios_watcher/tree/chain-indexer)

- Fix process naming for ChainSync clients. Given different process names and ids as options, multiple clients are now supported.

### Changed

- StateQuery.send_query interface. Now accepts queries as strings from user input.

### Fixed

- Avoid race condition on state queries by blocking until connection with the Ogmios server is established.

## [v0.2.0](https://github.com/wowica/xogmios/releases/tag/v0.2.0) (2024-02-24)

## Added

- Support for Tx Submission procotol
  - Submit signed transactions
  - Evaluate execution units of given transaction

## [v0.1.0](https://github.com/wowica/xogmios/releases/tag/v0.1.0) (2024-02-13)

### Added

- Support for Chain Sync protocol
- Partial support for Ledger State Queries:
  - epoch
  - eraStart
