**[English](CHANGELOG.md)** | **[繁體中文](CHANGELOG.zh-TW.md)** | **[简体中文](CHANGELOG.zh-CN.md)** | **[日本語](CHANGELOG.ja.md)**

# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `LICENSE` (Apache 2.0) and CI / License badges in
  `README.md` + 3 translated READMEs (#6). Fresh add
  -- repo previously had no LICENSE and no badges. Aligns with
  the org-wide Apache 2.0 migration tracked across 17 sister
  repos.

### Added
- **`call-publish` job in `main.yaml`**: opts into template v0.20.0's
  new `publish-worker.yaml` reusable workflow (template#232 / template#233).
  On tag push, each of the 4 matrix variants publishes a Docker image
  to `ghcr.io/ycpss91255-docker/ros2_distro:<tag>-<entry-name>`, and the
  default variant (`humble-desktop-full`) additionally publishes
  `:latest-humble-desktop-full`. Auth via GITHUB_TOKEN (no extra
  secrets); `target: devel`.

  **Consumption pattern: CI build cache only.** These published images
  are NOT intended as a Docker `FROM` base for downstream app repos.
  Future app-pair consolidations (urg_node / realsense / sick) keep
  their own self-contained Dockerfile that `FROM`s upstream
  `osrf/ros:` / `ros:` directly; their CI may pass
  `cache-from: type=registry,ref=ghcr.io/.../ros2_distro:<tag>-<variant>`
  to BuildKit as a best-effort hint to skip the cached sys/base/devel
  layers. When GHCR is unreachable (air-gapped, firewalled networks),
  app builds fall through to the full upstream rebuild without
  failing -- no hard dependency on GHCR.

### Changed
- Template subtree upgraded to `v0.20.0` (was `v0.19.0`).
  `main.yaml` reusable-workflow `@tag` references bumped accordingly.
- README.md aligned to the template framework reference applied in
  ycpss91255-docker/ros1_bridge#63 (merge 148c411): added CI status
  badge under the H1 title, promoted the `> **TL;DR**` blockquote into
  a `## TL;DR` H2, added a `## Overview` H2 explaining the two-repo
  consolidation rationale, extended the TOC to include the new
  sections, and corrected the Directory Structure tree (wrapper rows
  now point at `template/script/docker/<name>`; obsolete
  `.template_version` row dropped, version now lives in
  `template/.version`). Translations untouched -- they will be
  fanned out in a follow-up PR.

## [v0.1.0] - 2026-05-07

### Added
- **Initial release.** Single repo, single Dockerfile, single `BASE_IMAGE`
  ARG to switch ROS 2 distro / variant at build time. Replaces the two
  legacy repos `ros2_humble` and `osrf_ros2_humble` -- both shared 90%
  of their Dockerfile and diverged only on the `FROM` line.
- Default `BASE_IMAGE` is `osrf/ros:humble-desktop-full-jammy`. Common
  alternatives are listed in the Dockerfile header comment and in the
  README's Build targets section: humble (jammy) + jazzy (noble) + iron
  (jammy, legacy), with `ros:` (custom, amd64+arm64) and `osrf/ros:`
  (desktop / desktop-full, amd64) variants for each.
- Distro- and variant-agnostic smoke test: GUI assertions
  (`rviz2` / `rqt`) skip cleanly when their binaries aren't in the chosen
  variant; `gazebo` test handles both classic (humble) and Gazebo
  Harmonic (`gz`, jazzy+).
- Uses the `TEST_TOOLS_IMAGE` Dockerfile pattern from template v0.18.0+
  (no inline `bats-src` / `bats-extensions` / `lint-tools` stages); the
  saving versus the legacy two-repo split is roughly -50 lines net.
- **`build` stage between `devel` and `runtime`**: contract slot for
  downstream consumers to compile their packages. Empty no-op upstream
  (just `mkdir /opt/ros/install`); downstream forks override
  `FROM devel AS build` with `colcon build --install-base /opt/ros/install
  --merge-install` (or equivalent). `runtime` `COPY --from=build
  /opt/ros/install/` so the production image contains only binaries,
  no `src/` / `build/` / `.colcon-build` artifacts. README's Architecture
  section documents the full layer cake.
- **CI build matrix (4 entries / push)**: `humble-desktop-full` (osrf,
  default), `humble-ros-base` (ros:, cross-registry), `jazzy-desktop-full`
  (osrf, validates noble's deb822 apt format and Gazebo Harmonic `gz`),
  `jazzy-ros-base` (ros:). `ros-core` and Iron (EOL) intentionally
  excluded; see project README for rationale.
- Template subtree pinned at v0.19.0.
