# TEST.md

**33 tests** in `test/smoke/ros2_env.bats`, plus shared smoke tests from
`template/test/smoke/` (script_help + display_env, ~27 more).

The suite is **distro- and variant-agnostic**: variant-specific tests
(GUI tools / Gazebo) `skip` cleanly when the chosen `BASE_IMAGE` doesn't
include the binary, so the same suite works across:

- `ros:<distro>-ros-core-*` (minimal -- ros2 daemon only)
- `ros:<distro>-ros-base-*` (CLI tools available -- GUI tests skip)
- `osrf/ros:<distro>-desktop-*` (GUI tools added)
- `osrf/ros:<distro>-desktop-full-*` (full Gazebo + perception)

The Gazebo assertion accepts either the classic `gazebo` binary
(humble + earlier) or the Gazebo Harmonic `gz` binary (jazzy+).

## test/smoke/ros2_env.bats (33)

### ROS environment (8)

| Test | Description |
|------|-------------|
| `ROS_DISTRO is set` | Verify `ROS_DISTRO` env var is non-empty (no version assert) |
| `ROS setup.bash exists` | `/opt/ros/${ROS_DISTRO}/setup.bash` present |
| `ROS environment can be sourced` | Sourcing setup.bash exits 0 |
| `ros2 CLI is available after sourcing ROS` | `ros2` on PATH |
| `ros2 --help works` | `ros2 --help` exits 0 |
| `colcon command is available` | `colcon` on PATH |
| `colcon --help works` | `colcon --help` exits 0 |
| `rosdep is available` | `rosdep` on PATH |

### GUI tools — desktop / desktop-full only (3)

| Test | Description |
|------|-------------|
| `rviz2 command is available (desktop / desktop-full)` | Skip on ros-base / ros-core |
| `rqt command is available (desktop / desktop-full)` | Skip on ros-base / ros-core |
| `gazebo binary exists (desktop-full only; classic 'gazebo' for humble, 'gz' for jazzy)` | Skip on non-desktop-full |

### Base tools (11)

`python3` / `pip3` / `git` / `vim` / `curl` / `wget` / `tmux` / `tree` /
`htop` / `sudo` / `sudo -n` -- all on PATH and (sudo) usable without
password.

### System (11)

| Test | Description |
|------|-------------|
| `user is not root` | Container runs as non-root |
| `HOME is set and exists` | `$HOME` set and directory present |
| `timezone is Asia/Taipei` | `/etc/timezone` matches |
| `LANG is en_US.UTF-8` | Locale env var |
| `LC_ALL is en_US.UTF-8` | Locale env var |
| `NVIDIA_VISIBLE_DEVICES is set` | NVIDIA runtime env var |
| `NVIDIA_DRIVER_CAPABILITIES is set` | NVIDIA runtime env var |
| `entrypoint.sh exists and is executable` | `/entrypoint.sh` ready |
| `work directory exists` | `${HOME}/work` directory present |
| `work directory is writable` | Touch + rm works in `${HOME}/work` |
| `bash-completion is installed` | `/usr/share/bash-completion/bash_completion` present |

## Shared tests from template

The Dockerfile's `test` stage also runs the shared smoke specs from
`template/test/smoke/` (`script_help.bats` for the four wrapper scripts'
`-h` / `--help` / `--lang` behaviour, and `display_env.bats` for the
generated `compose.yaml`'s GUI block). See the template repo for the
exact list; new repo inherits them automatically via the
`COPY template/test/smoke/ /smoke_test/` line in the Dockerfile's
`test` stage.
