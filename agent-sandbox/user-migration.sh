#!/bin/bash
set -euo pipefail

BUILD_USERNAME=$(getent passwd 1000 | cut -d: -f1)
BUILD_GROUPNAME=$(getent group 1000 | cut -d: -f1)

TARGET_USERNAME=${USERNAME:-$BUILD_USERNAME}

if [ "$TARGET_USERNAME" != "$BUILD_USERNAME" ]; then
    echo "Migrating username from '$BUILD_USERNAME' to '$TARGET_USERNAME'..."

    groupmod -n "$TARGET_USERNAME" "$BUILD_GROUPNAME"
    usermod -l "$TARGET_USERNAME" -d "/home/$TARGET_USERNAME" "$BUILD_USERNAME"

    if [ -d "/home/$BUILD_USERNAME" ]; then
        mv "/home/$BUILD_USERNAME" "/home/$TARGET_USERNAME"
    fi

    if [ -f "/home/$TARGET_USERNAME/.zshrc" ]; then
        sed -i "s|/home/$BUILD_USERNAME/|/home/$TARGET_USERNAME/|g" "/home/$TARGET_USERNAME/.zshrc"
        sed -i "s|$BUILD_USERNAME|$TARGET_USERNAME|g" "/home/$TARGET_USERNAME/.zshrc"
    fi

    chown -R "$TARGET_USERNAME":"$TARGET_USERNAME" \
        "/home/$TARGET_USERNAME" \
        /usr/local/share/npm-global \
        /commandhistory

    echo "${TARGET_USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${TARGET_USERNAME}-nopasswd && \
    chmod 0440 /etc/sudoers.d/${TARGET_USERNAME}-nopasswd

    echo "Migration completed: $BUILD_USERNAME (uid:1000) -> $TARGET_USERNAME (uid:1000)"
else
    echo "Using existing user: $TARGET_USERNAME (uid:1000)"
fi
