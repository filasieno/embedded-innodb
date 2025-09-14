# Agent Development Guide

A file for [guiding coding agents](https://agents.md/).

## Commands

- **Build:** `nix build -L`
- **Enter the development shell:** `nix develop`
- **Within the development shell:**
  - **Configure the build:** "ib-configure"
  - **Build:** "ib-build"


## Directory Structure

- Shared Zig core:          `src/`
- nix build support source: `nix/`
- Public C++ API:           `innodb.h`
