# Pinger

A lightweight macOS menu bar app that continuously pings a host and color-codes connectivity.

## Status indicators

| Color | Meaning |
|-------|---------|
| 🟢 Green `● 12ms` | Good connectivity |
| 🟡 Yellow `● 250ms` | High latency (above threshold) |
| 🔴 Red blinking `●` | Unreachable / packet loss |

## Configuration

Click the menu bar icon → **Configure…** (or ⌘,) to change:

- **Host** — destination to ping (default: `8.8.8.8`)
- **Warn threshold** — latency in ms above which the indicator turns yellow (default: `200`)
- **Ping interval** — seconds between pings (default: `1.0`, minimum: `0.5`)

Settings are saved automatically and persist across restarts.

## Building

Requires macOS 26 with Command Line Tools 26.4+.

```sh
./build.sh
```

This compiles directly with `swiftc` (Swift Package Manager is not used, due to a CLT bug on macOS 26).

## Running

```sh
./Pinger
```

The app runs as a menu bar agent — no Dock icon. To stop it, use **Quit Pinger** from the menu.

## Run at login

Add the `Pinger` binary to **System Settings → General → Login Items**.
