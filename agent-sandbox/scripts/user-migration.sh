#!/bin/bash
set -euo pipefail

BUILD_USERNAME=$(getent passwd 1000 | cut -d: -f1)
BUILD_GROUPNAME=$(getent group 1000 | cut -d: -f1)
BUILD_HOME=$(getent passwd 1000 | cut -d: -f6)

TARGET_USERNAME=${USERNAME:-$BUILD_USERNAME}

if [ "$TARGET_USERNAME" != "$BUILD_USERNAME" ]; then
    echo "Migrating username from '$BUILD_USERNAME' to '$TARGET_USERNAME'..."

    # Change only the username, keep the same home directory and UID
    groupmod -n "$TARGET_USERNAME" "$BUILD_GROUPNAME"
    usermod -l "$TARGET_USERNAME" "$BUILD_USERNAME"

    if [ -f "$BUILD_HOME/.zshrc" ]; then
        sed -i "s|export LANG=.*|export LANG='${LANG}'|g" "$BUILD_HOME/.zshrc"
        sed -i "s|export LANGUAGE=.*|export LANGUAGE='${LANGUAGE}'|g" "$BUILD_HOME/.zshrc"
        sed -i "s|export LC_ALL=.*|export LC_ALL='${LC_ALL}'|g" "$BUILD_HOME/.zshrc"
    fi

    # Update sudoers file
    echo "${TARGET_USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${TARGET_USERNAME}-nopasswd && \
    chmod 0440 /etc/sudoers.d/${TARGET_USERNAME}-nopasswd

    echo "Migration completed: $BUILD_USERNAME (uid:1000) -> $TARGET_USERNAME (uid:1000)"
    echo "Home directory: $BUILD_HOME (unchanged)"
else
    echo "Using existing user: $TARGET_USERNAME (uid:1000)"
fi
