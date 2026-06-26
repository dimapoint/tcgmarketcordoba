# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**tcgmarketcordoba** is a Trading Card Game (TCG) marketplace app for Córdoba. It consists of:
- A **Flutter frontend** targeting Android, iOS, web, Windows, macOS, and Linux
- A **Go backend** (`backend/`) — currently initialized but not yet developed

## Commands

### Flutter (frontend)

```bash
# Get dependencies
flutter pub get

# Run the app (choose a target device)
flutter run

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Analyze/lint
flutter analyze

# Build for Android
flutter build apk

# Build for web
flutter build web
```

### Go (backend)

```bash
cd backend

# Tidy dependencies
go mod tidy

# Run the server (once a main package exists)
go run .

# Run tests
go test ./...
```

## Architecture

### Flutter App

- Entry point: `lib/main.dart`
- Currently scaffolded as the default Flutter counter template — actual app features are not yet implemented
- Linting via `flutter_lints` (`analysis_options.yaml` at root)

### Go Backend

- Module: `tcgmarketcordoba` (`backend/go.mod`)
- No source files yet — to be built out alongside the Flutter app

## Platform Support

The project targets all six Flutter platforms: Android, iOS, web, Windows, macOS, Linux. Platform-specific configs live in `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` directories respectively.
