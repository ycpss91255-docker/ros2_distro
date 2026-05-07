#!/usr/bin/env bats

setup() {
    load "${BATS_TEST_DIRNAME}/test_helper"
}

# Tests are written distro-agnostic and variant-agnostic. Variant-specific
# tools (GUI / sim / full perception stack) skip cleanly when the binary
# is absent so the same suite is reusable across:
#   - ros:<distro>-ros-core-* (minimal -- ros2 daemon only)
#   - ros:<distro>-ros-base-* (CLI tools available)
#   - osrf/ros:<distro>-desktop-* (GUI tools added)
#   - osrf/ros:<distro>-desktop-full-* (Gazebo etc. added)

# -------------------- ROS environment --------------------

@test "ROS_DISTRO is set" {
    assert [ -n "${ROS_DISTRO}" ]
}

@test "ROS setup.bash exists" {
    assert [ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]
}

@test "ROS environment can be sourced" {
    run bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && echo ok"
    assert_success
    assert_output "ok"
}

@test "ros2 CLI is available after sourcing ROS" {
    run bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && command -v ros2"
    assert_success
}

@test "ros2 --help works" {
    run bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && ros2 --help"
    assert_success
}

@test "colcon command is available" {
    run command -v colcon
    assert_success
}

@test "colcon --help works" {
    run colcon --help
    assert_success
}

@test "rosdep is available" {
    run command -v rosdep
    assert_success
}

# -------------------- GUI tools (desktop / desktop-full only) --------------------

@test "rviz2 command is available (desktop / desktop-full)" {
    run bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && command -v rviz2"
    if [ "${status}" -ne 0 ]; then
        skip "no rviz2 -- ros-base / ros-core variant"
    fi
    assert_success
}

@test "rqt command is available (desktop / desktop-full)" {
    run bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && command -v rqt"
    if [ "${status}" -ne 0 ]; then
        skip "no rqt -- ros-base / ros-core variant"
    fi
    assert_success
}

@test "gazebo binary exists (desktop-full only; classic 'gazebo' for humble, 'gz' for jazzy)" {
    if command -v gazebo >/dev/null 2>&1; then
        :  # humble / older: classic gazebo binary
    elif command -v gz >/dev/null 2>&1; then
        :  # jazzy+: Gazebo Harmonic ships `gz` instead
    else
        skip "no gazebo / gz binary -- non-desktop-full variant"
    fi
}

# -------------------- Base tools --------------------

@test "python3 is available" {
    run which python3
    assert_success
}

@test "pip3 is available" {
    run which pip3
    assert_success
}

@test "git is available" {
    run which git
    assert_success
}

@test "vim is available" {
    run which vim
    assert_success
}

@test "curl is available" {
    run which curl
    assert_success
}

@test "wget is available" {
    run which wget
    assert_success
}

@test "tmux is available" {
    run which tmux
    assert_success
}

@test "tree is available" {
    run which tree
    assert_success
}

@test "htop is available" {
    run which htop
    assert_success
}

@test "sudo is available" {
    run which sudo
    assert_success
}

@test "sudo works without password" {
    run sudo -n true
    assert_success
}

# -------------------- System --------------------

@test "user is not root" {
    run id -u
    assert_success
    refute_output "0"
}

@test "HOME is set and exists" {
    assert [ -n "${HOME}" ]
    assert [ -d "${HOME}" ]
}

@test "timezone is Asia/Taipei" {
    run cat /etc/timezone
    assert_success
    assert_output "Asia/Taipei"
}

@test "LANG is en_US.UTF-8" {
    assert_equal "${LANG}" "en_US.UTF-8"
}

@test "LC_ALL is en_US.UTF-8" {
    assert_equal "${LC_ALL}" "en_US.UTF-8"
}

@test "NVIDIA_VISIBLE_DEVICES is set" {
    assert_equal "${NVIDIA_VISIBLE_DEVICES}" "all"
}

@test "NVIDIA_DRIVER_CAPABILITIES is set" {
    assert_equal "${NVIDIA_DRIVER_CAPABILITIES}" "all"
}

@test "entrypoint.sh exists and is executable" {
    assert [ -x "/entrypoint.sh" ]
}

@test "work directory exists" {
    assert [ -d "${HOME}/work" ]
}

@test "work directory is writable" {
    run bash -c "touch '${HOME}/work/.smoke_test' && rm '${HOME}/work/.smoke_test'"
    assert_success
}

@test "bash-completion is installed" {
    assert [ -f "/usr/share/bash-completion/bash_completion" ]
}
