# Pinger

A lightweight macOS menu bar app that continuously pings a host and color-codes connectivity. Stores ping history locally and tracks VPN usage.

## Status indicators

| Color | Meaning |
|-------|---------|
| 🟢 Green `● 12ms` | Good connectivity |
| 🟡 Yellow `● 250ms` | High latency (above threshold) |
| 🔴 Red blinking `●` | Unreachable / packet loss |

## Features

- **Live latency display** in the menu bar
- **Ping history** stored in a local SQLite database with automatic bucketing:
  - 1-second resolution for the last 24 hours
  - 1-minute resolution for the last 30 days
  - 1-hour resolution for the last year
- **VPN detection** — automatically detects when a VPN is active (supports CatoClient, WireGuard, OpenVPN, Cisco AnyConnect, and any VPN using `utun`/`ppp`/`ipsec` interfaces)
- **History window** with a live-updating line chart, segmented by time range (1h / 24h / 30d / 1y), and stats broken down by VPN on/off

## Menu

| Item | Action |
|------|--------|
| History… (`⌘H`) | Open the ping history chart |
| Configure… (`⌘,`) | Open settings |
| Quit Pinger (`⌘Q`) | Exit the app |

## Configuration

Click the menu bar icon → **Configure…** to change:

- **Host** — destination to ping (default: `8.8.8.8`)
- **Warn threshold** — latency in ms above which the indicator turns yellow (default: `200`)
- **Ping interval** — seconds between pings (default: `1.0`, minimum: `0.5`)
- **Clear History…** — permanently delete all recorded ping data

Settings are saved automatically and persist across restarts.

## History window

The history chart shows latency over time with:
- **Blue line** — average latency per bucket
- **Red ticks** at the bottom — unreachable pings
- **Blue shading** — time ranges where VPN was active
- **Stats panel** — avg / min / max broken down for Overall, VPN on, and VPN off

## Building

Requires macOS 26 with Command Line Tools 26.4+.

```sh
./build.sh
```

Produces `Pinger.app` in the current directory. Compiles directly with `swiftc` (Swift Package Manager is not used due to a CLT bug on macOS 26).

## Running

Double-click `Pinger.app`, or:

```sh
open Pinger.app
```

The app runs as a menu bar agent — no Dock icon, no console window. To stop it, use **Quit Pinger** from the menu.

## Run at login

Add `Pinger.app` to **System Settings → General → Login Items**.
