# ros2_distro -- ROS 2 multi-distro Docker environment.
#
# Default: osrf/ros:humble-desktop-full-jammy (Ubuntu 22.04, full GUI + simulators).
#
# Override BASE_IMAGE to switch distro / variant. Any image whose layout
# matches `/opt/ros/<distro>/setup.bash` works.
#
#   ROS 2 Humble (Ubuntu 22.04 jammy, supported until 2027-05):
#     osrf/ros:humble-desktop-full-jammy   (default -- full GUI + Gazebo + RViz2)
#     osrf/ros:humble-desktop-jammy        (GUI minus simulators)
#     ros:humble-ros-base-jammy            (custom base, headless, smallest)
#     ros:humble-ros-core-jammy            (minimal core)
#
#   ROS 2 Jazzy (Ubuntu 24.04 noble, supported until 2029-05):
#     osrf/ros:jazzy-desktop-full-noble    (full GUI + Gazebo Harmonic + RViz2)
#     osrf/ros:jazzy-desktop-noble         (GUI minus simulators)
#     ros:jazzy-ros-base-noble             (custom base, headless)
#     ros:jazzy-ros-core-noble             (minimal core)
#
#   ROS 2 Iron (Ubuntu 22.04 jammy, EOL 2024-11 -- legacy):
#     osrf/ros:iron-desktop-full-jammy
#     ros:iron-ros-base-jammy
#
# Build:
#   ./build.sh                                                            # default target
#   ./build.sh --build-arg BASE_IMAGE=osrf/ros:jazzy-desktop-full-noble   # jazzy with GUI
#   ./build.sh --build-arg BASE_IMAGE=ros:humble-ros-base-jammy           # humble headless
#
# ROS_DISTRO comes from BASE_IMAGE's own ENV (every official ros: /
# osrf/ros: image sets `ENV ROS_DISTRO=<distro>`); subsequent stages
# read ${ROS_DISTRO} directly without needing a separate ARG.
ARG BASE_IMAGE="osrf/ros:humble-desktop-full-jammy"
ARG TEST_TOOLS_IMAGE="test-tools:local"

############################## sys ##############################
FROM ${BASE_IMAGE} AS sys

ARG USER="initial"
ARG GROUP="initial"
ARG UID="1000"
ARG GID="${UID}"
ARG SHELL="/bin/bash"
ARG HARDWARE="x86_64"
ENV HOME="/home/${USER}"

# Env vars for nvidia-container-runtime.
ENV NVIDIA_VISIBLE_DEVICES="all"
ENV NVIDIA_DRIVER_CAPABILITIES="all"

SHELL ["/bin/bash", "-x", "-euo", "pipefail", "-c"]

# Sanity-check ROS_DISTRO inherited from BASE_IMAGE.
RUN [ -n "${ROS_DISTRO:-}" ] && [ -d "/opt/ros/${ROS_DISTRO}" ] || { \
        echo "FATAL: ROS_DISTRO unset or /opt/ros/${ROS_DISTRO:-?} missing -- is BASE_IMAGE a ros: / osrf/ros: image?" >&2; \
        exit 1; \
    }

# Setup users and groups
RUN if getent group "${GID}" >/dev/null; then \
        existing_grp="$(getent group "${GID}" | cut -d: -f1)"; \
        if [ "${existing_grp}" != "${GROUP}" ]; then \
            groupmod -n "${GROUP}" "${existing_grp}"; \
        fi; \
    else \
        groupadd -g "${GID}" "${USER}"; \
    fi; \
    \
    if getent passwd "${UID}" >/dev/null; then \
        existing_user="$(getent passwd "${UID}" | cut -d: -f1)"; \
        if [ "${existing_user}" != "${USER}" ]; then \
            usermod -l "${USER}" "${existing_user}"; \
        fi; \
        usermod -g "${GID}" -s "${SHELL}" -d "${HOME}" -m "${USER}"; \
    elif id -u "${USER}" >/dev/null 2>&1; then \
        usermod -u "${UID}" -g "${GID}" -s "${SHELL}" -d "/home/${USER}" -m "${USER}"; \
    else \
        useradd -u "${UID}" -g "${GID}" -s "${SHELL}" -m "${USER}"; \
    fi; \
    \
    mkdir -p /etc/sudoers.d; \
    echo "${USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${USER}"; \
    chmod 0440 "/etc/sudoers.d/${USER}"

# Setup locale, timezone and replace apt urls (Taiwan mirror)
ENV TZ="Asia/Taipei"
ENV LC_ALL="en_US.UTF-8"
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"

ARG APT_MIRROR_UBUNTU="tw.archive.ubuntu.com"
RUN sed -i "s@archive.ubuntu.com@${APT_MIRROR_UBUNTU}@g" /etc/apt/sources.list || true && \
    sed -i "s@archive.ubuntu.com@${APT_MIRROR_UBUNTU}@g" /etc/apt/sources.list.d/ubuntu.sources || true && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        tzdata \
        locales && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen "${LANG}" && \
    update-locale LANG="${LANG}" && \
    ln -snf /usr/share/zoneinfo/"${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone

############################## base ##############################
FROM sys AS base

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sudo \
        psmisc \
        htop \
        # Shell
        tmux \
        terminator \
        # base tools
        ca-certificates \
        software-properties-common \
        wget \
        curl \
        git \
        vim \
        tree \
        # python3 tools
        python3-pip \
        python3-dev \
        python3-setuptools \
        bash-completion \
        # ROS 2 build tooling (colcon comes preinstalled in ros: / osrf/ros:
        # base/desktop variants; these add convenience features)
        python3-colcon-common-extensions \
        python3-rosdep \
        python3-vcstool \
        # GPU/OpenGL (Intel + software fallback; harmless on headless variants)
        libgl1-mesa-dri \
        libgl1-mesa-glx \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

############################## devel ##############################
FROM base AS devel

ARG USER
ARG GROUP
ARG ENTRYPOINT_FILE="script/entrypoint.sh"
ARG CONFIG_DIR="/tmp/config"
# <repo>/config is a per-repo copy of template/config seeded by init.sh.
# Edit files there freely; template upgrades do not touch this directory.
ARG CONFIG_SRC="config"

# ROS 2 dev tools. plotjuggler-ros packaging varies by distro -- humble
# has it, jazzy may not yet. Install best-effort to keep multi-distro
# build path working.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        "ros-${ROS_DISTRO}-plotjuggler-ros" \
        || echo "plotjuggler-ros not packaged for ROS_DISTRO=${ROS_DISTRO}, skipping"; \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 "./${ENTRYPOINT_FILE}" "/entrypoint.sh"
COPY --chown="${USER}":"${GROUP}" --chmod=0755 "${CONFIG_SRC}" "${CONFIG_DIR}"

USER "${USER}"

RUN "${CONFIG_DIR}"/pip/setup.sh

# Setup shell, terminator, tmux
RUN cat "${CONFIG_DIR}"/shell/bashrc >> "${HOME}/.bashrc" && \
    chown "${USER}":"${GROUP}" "${HOME}/.bashrc" && \
    "${CONFIG_DIR}"/shell/terminator/setup.sh && \
    "${CONFIG_DIR}"/shell/tmux/setup.sh && \
    sudo rm -rf "${CONFIG_DIR}"

WORKDIR "${HOME}/work"

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

############################## test (ephemeral) ##############################
# Resolves to test-tools:local (local build.sh) or ghcr.io/.../test-tools:vX.Y.Z (CI).
FROM ${TEST_TOOLS_IMAGE} AS test-tools-stage

FROM devel AS test

USER root

# Lint tools (from pre-built test-tools image; see TEST_TOOLS_IMAGE at top)
COPY --from=test-tools-stage /usr/local/bin/shellcheck /usr/local/bin/shellcheck
COPY --from=test-tools-stage /usr/local/bin/hadolint /usr/local/bin/hadolint

# Lint: ShellCheck (.sh) + Hadolint (Dockerfile)
COPY .hadolint.yaml /lint/.hadolint.yaml
COPY Dockerfile /lint/Dockerfile
COPY *.sh /lint/
COPY template/script/docker/_lib.sh \
     template/script/docker/i18n.sh \
     template/script/docker/_tui_conf.sh \
     /lint/
RUN shellcheck -S warning /lint/*.sh
RUN cd /lint && hadolint Dockerfile

# Bats (from pre-built test-tools image; see TEST_TOOLS_IMAGE at top)
COPY --from=test-tools-stage /opt/bats /opt/bats
COPY --from=test-tools-stage /usr/lib/bats /usr/lib/bats
RUN ln -sf /opt/bats/bin/bats /usr/local/bin/bats

ENV BATS_LIB_PATH="/usr/lib/bats"

# Smoke test (shared tests from template + repo-specific tests)
COPY template/test/smoke/ /smoke_test/
COPY test/smoke/ /smoke_test/

ARG USER
USER "${USER}"

RUN bats /smoke_test/

############################## runtime-base ##############################
FROM sys AS runtime-base

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sudo \
        tini \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

############################## runtime ##############################
FROM runtime-base AS runtime

ARG USER

# Install only the ROS packages required to run your nodes.
# Customize this list for your application.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        "ros-${ROS_DISTRO}-rclpy" \
        "ros-${ROS_DISTRO}-rclcpp" \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 script/entrypoint.sh /entrypoint.sh

USER "${USER}"
WORKDIR "${HOME}/work"

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
