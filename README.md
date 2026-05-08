# ros2_distro -- ROS 2 Multi-distro Docker Environment

[![CI](https://github.com/ycpss91255-docker/ros2_distro/actions/workflows/main.yaml/badge.svg)](https://github.com/ycpss91255-docker/ros2_distro/actions/workflows/main.yaml) [![License](https://img.shields.io/badge/License-Apache--2.0-blue?style=flat-square)](./LICENSE)

[![CI](https://github.com/ycpss91255-docker/ros2_distro/actions/workflows/main.yaml/badge.svg)](https://github.com/ycpss91255-docker/ros2_distro/actions/workflows/main.yaml)

One-command ROS 2 containerized dev environment. Single Dockerfile, single `BASE_IMAGE` ARG to switch between Humble / Jazzy / Iron and `ros:` (headless) / `osrf/ros:` (desktop / desktop-full) at build time.

**[English](README.md)** | **[繁體中文](doc/README.zh-TW.md)** | **[简体中文](doc/README.zh-CN.md)** | **[日本語](doc/README.ja.md)**

---

## Table of Contents

- [TL;DR](#tldr)
- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [Build targets](#build-targets)
- [Usage](#usage)
- [Usage as Subtree](#usage-as-subtree)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Smoke Tests](#smoke-tests)
- [Directory Structure](#directory-structure)
- [Updating docker\_template](#updating-template)

---

## TL;DR

```bash
./build.sh && ./run.sh                                                  # default: humble desktop-full
./build.sh --build-arg BASE_IMAGE=osrf/ros:jazzy-desktop-full-noble     # jazzy with GUI
./build.sh --build-arg BASE_IMAGE=ros:humble-ros-base-jammy             # humble headless
```

See [Build targets](#build-targets) for the full list.

## Overview

`ros2_distro` consolidates the two legacy single-distro repos
(`ros2_humble`, `osrf_ros2_humble`) into one Dockerfile parameterized
by `BASE_IMAGE`, and extends coverage to Jazzy (Ubuntu 24.04 noble)
and Iron. The legacy repos shared 90% of their Dockerfile and diverged
only on the `FROM` line, so collapsing them removes a long-standing
maintenance burden: a single fix in `sys` / `base` / `devel` now
reaches every ROS 2 distro and registry combination at once. Default
is `osrf/ros:humble-desktop-full-jammy`; CI exercises a 4-entry matrix
(humble / jazzy, `ros:` / `osrf/ros:`) on every push, including
noble's deb822 apt sources and the `gazebo` (humble classic) vs `gz`
(jazzy Harmonic) divergence.

## Features

- **Multi-distro**: switch between Humble / Jazzy / Iron via `BASE_IMAGE` ARG; same Dockerfile, no fork.
- **Both registries**: `ros:` (custom, headless, smaller; arm64 + amd64) and `osrf/ros:` (desktop / desktop-full with RViz2 / Gazebo; amd64 only).
- **Multi-stage build**: sys → base → devel / test / runtime, choose as needed.
- **Smoke Test**: Bats tests run automatically during build; distro- and variant-agnostic (GUI tests skip cleanly on `ros-base` / `ros-core`; humble's `gazebo` and jazzy's `gz` are both detected).
- **Docker Compose**: single `compose.yaml` manages all targets.
- **Auto-detection**: `setup.sh` auto-detects UID/GID/workspace, generates `.env`.
- **Modular config**: shell config managed via [template](https://github.com/ycpss91255-docker/template) subtree.
- **X11 forwarding**: supports GUI applications when using a desktop variant.

> **Note**: `osrf/ros:*` variants ship amd64 binaries only. For arm64 (Jetson, Raspberry Pi), pick a `ros:` variant -- that registry publishes both architectures.

## Quick Start

```bash
# 1. Build dev environment (auto-generates .env on first run)
./build.sh

# 2. Start container
./run.sh

# 3. Enter a running container
./exec.sh

# Or use docker compose directly
docker compose up -d devel
docker compose exec devel bash
docker compose down
```

## Build targets

Override `BASE_IMAGE` to switch distro / variant. `ROS_DISTRO` is read from
the base image's own `ENV ROS_DISTRO=<distro>`, so you don't need to keep
ARGs in sync.

### ROS 2 Humble (Ubuntu 22.04 jammy, supported until 2027-05)

| `BASE_IMAGE` | What it ships | Architectures |
|---|---|---|
| `osrf/ros:humble-desktop-full-jammy` | Full GUI + RViz2 + Gazebo Classic + perception (**default**) | amd64 |
| `osrf/ros:humble-desktop-jammy` | GUI minus simulators | amd64 |
| `ros:humble-ros-base-jammy` | Headless, smallest CLI | amd64 + arm64 |
| `ros:humble-ros-core-jammy` | Minimal core | amd64 + arm64 |

### ROS 2 Jazzy (Ubuntu 24.04 noble, supported until 2029-05)

| `BASE_IMAGE` | What it ships | Architectures |
|---|---|---|
| `osrf/ros:jazzy-desktop-full-noble` | Full GUI + RViz2 + Gazebo Harmonic (`gz`) + perception | amd64 |
| `osrf/ros:jazzy-desktop-noble` | GUI minus simulators | amd64 |
| `ros:jazzy-ros-base-noble` | Headless | amd64 + arm64 |
| `ros:jazzy-ros-core-noble` | Minimal core | amd64 + arm64 |

### ROS 2 Iron (Ubuntu 22.04 jammy, EOL 2024-11 — kept for legacy)

| `BASE_IMAGE` | What it ships | Architectures |
|---|---|---|
| `osrf/ros:iron-desktop-full-jammy` | Full GUI + simulators | amd64 |
| `ros:iron-ros-base-jammy` | Headless | amd64 + arm64 |

### Persisting the override

Either pass `--build-arg` per `./build.sh` invocation, or persist the
override in `setup.conf` so subsequent builds pick it up automatically:

```ini
[build]
arg_4 = BASE_IMAGE=osrf/ros:jazzy-desktop-full-noble
```

The `[build] arg_*` slots flow into `compose.yaml`'s `build.args` via
`setup.sh`. Use the TUI editor to manage them: `./setup_tui.sh build`.

## Usage

### Development (devel)

Full dev environment with colcon, tmux, terminator, vim, git, etc.

```bash
./build.sh                       # Build (default: devel)
./build.sh --no-env test         # Build without refreshing .env
./run.sh                         # Start (default: devel)
./run.sh --no-env -d             # Background start, skip .env refresh
./exec.sh                        # Enter running container

docker compose build devel       # Equivalent command
docker compose run --rm devel    # One-off start
docker compose up -d devel       # Start in background
docker compose exec devel bash   # Enter running container
```

### Testing (test)

Smoke tests run automatically during build; build fails if tests fail.

```bash
./build.sh test
# or
docker compose --profile test build test
```

### Deployment (runtime)

Minimal image with only essential ROS 2 packages.

```bash
./build.sh runtime
./run.sh runtime
# or
docker compose --profile runtime build runtime
docker compose --profile runtime run --rm runtime
```

## Usage as Subtree

This repo can be embedded into another project via `git subtree`, letting the project carry its own Docker dev environment.

### Adding to Your Project

```bash
git subtree add --prefix=docker/osrf_ros2_humble \
    https://github.com/ycpss91255-docker/osrf_ros2_humble.git main --squash
```

Example directory structure after adding:

```text
my_robot_project/
├── src/                         # Project source code
├── docker/osrf_ros2_humble/     # Subtree
│   ├── build.sh
│   ├── run.sh
│   ├── compose.yaml
│   ├── Dockerfile
│   └── template/
└── ...
```

### Building and Running

```bash
cd docker/osrf_ros2_humble
./build.sh && ./run.sh
```

`build.sh` uses `--base-path` internally, so path detection works correctly regardless of where you run it from.

### Workspace Detection

<details>
<summary>Click to expand detection behavior when used as subtree</summary>

When the subtree sits at `my_robot_project/docker/osrf_ros2_humble/`:

- **IMAGE_NAME**: directory name is `osrf_ros2_humble` (not `docker_*`), so detection falls through to `.env.example` which has `IMAGE_NAME=osrf_ros2_humble` — works correctly.
- **WS_PATH**: strategy 1 (sibling scan) and strategy 2 (path traversal) may not match, so strategy 3 (fallback) resolves to the parent directory (`my_robot_project/docker/`).

**Recommendation**: after the first build, edit `WS_PATH` in `.env` to point to your actual workspace. The value is preserved on subsequent builds.

</details>

### Syncing with Upstream

```bash
git subtree pull --prefix=docker/osrf_ros2_humble \
    https://github.com/ycpss91255-docker/osrf_ros2_humble.git main --squash
```

> **Notes**:
> - Local modifications are tracked by git normally.
> - `subtree pull` may produce merge conflicts if upstream changed the same files you modified locally.
> - Do **not** modify `template/` inside the subtree — it is managed by the env repo's own subtree.

## Configuration

### .env Parameters

Automatically refreshed on every `./build.sh` or `./run.sh` (use `--no-env` to skip). Refer to `.env.example` to create manually:

| Variable | Description | Example |
|----------|-------------|---------|
| `USER_NAME` | Container username | `developer` |
| `USER_GROUP` | User group | `developer` |
| `USER_UID` | User UID (matches host) | `1000` |
| `USER_GID` | User GID (matches host) | `1000` |
| `HARDWARE` | Hardware architecture | `x86_64` |
| `DOCKER_HUB_USER` | Docker Hub username | `myuser` |
| `GPU_ENABLED` | GPU support | `true` / `false` |
| `IMAGE_NAME` | Image name | `osrf_ros2_humble` |
| `WS_PATH` | Workspace mount path | `/home/user/colcon_ws` |

### Auto-detection Details

`setup.sh` automatically detects system parameters and generates `.env`. The two most complex detections are documented below.

<details>
<summary>Click to expand detection logic</summary>

#### IMAGE_NAME Inference

Scans the repo directory path to derive the image name:

| Priority | Rule | Example Path | Result |
|:--------:|------|-------------|--------|
| 1 | Last directory matches `docker_*` → strip prefix | `/home/user/docker_osrf_ros2_humble` | `osrf_ros2_humble` |
| 2 | Scan path (right→left) for `*_ws` → use prefix | `/home/user/ros2_humble_ws/docker_osrf_ros2_humble` | `ros2_humble` |
| 3 | Read `IMAGE_NAME` from `.env.example` | — | value in `.env.example` |
| 4 | Fallback | — | `unknown` |

#### WS_PATH Workspace Detection

Three-strategy search to locate the workspace mount path:

| Priority | Strategy | Condition | Result |
|:--------:|----------|-----------|--------|
| 1 | Sibling scan | Current dir is `docker_*` and sibling `*_ws` exists | Sibling `*_ws` absolute path |
| 2 | Path traversal | Walk path upward, find first `*_ws` component | That `*_ws` directory |
| 3 | Fallback | None of the above | Parent directory of repo |

**Example** (strategy 1):
```
/home/user/
├── docker_osrf_ros2_humble/ ← repo (current dir)
└── osrf_ros2_humble_ws/     ← detected as WS_PATH
```

**Example** (strategy 2):
```
/home/user/colcon_ws/src/docker_osrf_ros2_humble/
                     ↑ found *_ws while traversing upward
```

> If `.env` already exists and `WS_PATH` points to a valid directory, detection is skipped and the existing value is preserved.

</details>

### Language

`setup.sh` displays messages in English by default. Use `--lang zh` for Chinese when running `build.sh`:

```bash
# Re-generate .env with Chinese prompts
rm .env
SETUP_LANG=zh ./build.sh
```

## Architecture

### Multi-stage build flow

```
                     BASE_IMAGE  (osrf/ros:* or ros:* — chosen via ARG)
                          │
                          ▼
                         sys  ───────────────────────┐
                          │                          │
                          ▼                          ▼
                         base                   runtime-base
                          │                          │
                          ▼                          ▼
                       devel  ─┐                  runtime  ◄────── COPY --from=build
                          │    │                                    /opt/ros/install/
                          ▼    │
        TEST_TOOLS ──►  test   └──► build  ─── compile your packages here,
        (external)              (downstream      output → /opt/ros/install/
                                 contract slot)
```

| Stage | Built FROM | Purpose | When |
|---|---|---|---|
| `sys` | `${BASE_IMAGE}` | OS base + user/group + locale + timezone + APT mirror (handles both legacy `sources.list` and noble's `ubuntu.sources` deb822) | Always |
| `base` | `sys` | Common dev tools (sudo / git / vim / tmux / terminator / python3 / colcon-common-extensions / rosdep / vcstool) | Always |
| `devel` | `base` | Full dev environment + plotjuggler + entrypoint + X11 forward | `./build.sh` default |
| `test` | `devel` + `${TEST_TOOLS_IMAGE}` | ShellCheck + Hadolint + Bats; ephemeral | `./build.sh test` (CI gate) |
| `build` | `devel` | **Downstream contract slot** — compile your code, output to `/opt/ros/install/` | Override in your fork |
| `runtime-base` | `sys` | Minimal runtime: sudo + tini | Always |
| `runtime` | `runtime-base` + `COPY --from=build` | Production image with binaries from `build` stage | `./build.sh runtime` |

### Downstream pattern: from devel to a release runtime

`ros2_distro` itself ships an empty `build` stage so the upstream image
builds cleanly (no `src/` required). Your downstream fork overrides that
stage to compile actual packages:

```dockerfile
# Your repo's Dockerfile (e.g. urg_node, realsense), inheriting from
# ros2_distro's layer cake. Insert this BETWEEN the inherited `devel`
# and `runtime` stages by re-declaring `FROM devel AS build` with content:

FROM devel AS build

ARG USER
ARG GROUP

USER root
COPY --chown=${USER}:${GROUP} src/ /home/${USER}/work/src/

# Resolve ROS 2 deps (rosdep) + compile (colcon).
RUN apt-get update && \
    rosdep install --from-paths /home/${USER}/work/src -y --ignore-src && \
    rm -rf /var/lib/apt/lists/*
USER ${USER}

RUN source /opt/ros/${ROS_DISTRO}/setup.bash && \
    cd /home/${USER}/work && \
    colcon build --install-base /opt/ros/install \
                 --merge-install \
                 --cmake-args -DCMAKE_BUILD_TYPE=Release
```

`runtime` then receives the install tree via the unchanged
`COPY --from=build /opt/ros/install/ /opt/ros/install/` line and your
production image only contains binaries — no `src/`, no `build/`, no
`.colcon-build` workspace state.

### CI build matrix

The CI workflow validates 4 BASE_IMAGE combinations on every push:

| # | BASE_IMAGE | Why |
|---|---|---|
| 1 | `osrf/ros:humble-desktop-full-jammy` | default; full GUI + Gazebo Classic |
| 2 | `ros:humble-ros-base-jammy` | cross-registry; verifies smoke tests skip GUI cleanly |
| 3 | `osrf/ros:jazzy-desktop-full-noble` | jazzy on noble (deb822 apt sources, Gazebo Harmonic `gz`) |
| 4 | `ros:jazzy-ros-base-noble` | jazzy + cross-registry |

`ros-core` and ROS 2 Iron (EOL) are intentionally not in the matrix; see
the project README for rationale.

## Smoke Tests

See [TEST.md](doc/test/TEST.md) for details.

## Directory Structure

```text
ros2_distro/
├── compose.yaml                              # Docker Compose definition
├── Dockerfile                                # Multi-stage build
├── build.sh -> template/script/docker/build.sh   # Symlink
├── run.sh -> template/script/docker/run.sh       # Symlink
├── exec.sh -> template/script/docker/exec.sh     # Symlink
├── stop.sh -> template/script/docker/stop.sh     # Symlink
├── Makefile -> template/script/docker/Makefile   # Symlink
├── .env.example                              # IMAGE_NAME fallback
├── .hadolint.yaml                            # Hadolint ignore rules
├── setup.conf                                # Repo override (selects BASE_IMAGE etc.)
├── script/
│   └── entrypoint.sh                         # Container entrypoint
├── doc/                                      # Translated READMEs + TEST + CHANGELOG
│   ├── README.zh-TW.md
│   ├── README.zh-CN.md
│   ├── README.ja.md
│   ├── test/TEST.md
│   └── changelog/CHANGELOG.md
├── test/smoke/                               # Repo-specific Bats environment tests
│   └── ros_env.bats
├── .github/workflows/
│   └── main.yaml                             # CI (calls template reusable workflows)
└── template/                                 # git subtree (version pinned in template/.version)
```

## Updating template

```bash
git subtree pull --prefix=template \
    https://github.com/ycpss91255-docker/template.git v1.4.0 --squash
```
