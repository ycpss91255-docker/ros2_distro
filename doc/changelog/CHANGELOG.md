**[English](CHANGELOG.md)** | **[繁體中文](CHANGELOG.zh-TW.md)** | **[简体中文](CHANGELOG.zh-CN.md)** | **[日本語](CHANGELOG.ja.md)**

# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
