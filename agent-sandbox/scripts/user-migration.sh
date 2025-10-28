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
        echo "Moving home directory contents..."
        mv -v "/home/$BUILD_USERNAME" "/home/$TARGET_USERNAME"
    fi

    if [ -f "/home/$TARGET_USERNAME/.zshrc" ]; then
        sed -i "s|/home/$BUILD_USERNAME/|/home/$TARGET_USERNAME/|g" "/home/$TARGET_USERNAME/.zshrc"
        sed -i "s|$BUILD_USERNAME|$TARGET_USERNAME|g" "/home/$TARGET_USERNAME/.zshrc"
        sed -i "s|export LANG=.*|export LANG='${LANG}'|g" "/home/$TARGET_USERNAME/.zshrc"
        sed -i "s|export LANGUAGE=.*|export LANGUAGE='${LANGUAGE}'|g" "/home/$TARGET_USERNAME/.zshrc"
        sed -i "s|export LC_ALL=.*|export LC_ALL='${LC_ALL}'|g" "/home/$TARGET_USERNAME/.zshrc"
    fi

    if [ -d "/home/$TARGET_USERNAME/.local/bin" ]; then
        for link in /home/$TARGET_USERNAME/.local/bin/*; do
            if [ -L "$link" ]; then
                target=$(readlink "$link")
                if [[ "$target" == *"/home/$BUILD_USERNAME/"* ]]; then
                    new_target="${target//\/home\/$BUILD_USERNAME\//\/home\/$TARGET_USERNAME\/}"
                    ln -sfn "$new_target" "$link"
                    echo "Updated symlink: $link -> $new_target"
                fi
            fi
        done
    fi

    chown -vR "$TARGET_USERNAME":"$TARGET_USERNAME" \
        "/home/$TARGET_USERNAME" \
        /usr/local/share/npm-global \
        /commandhistory \
        /configs

    echo "${TARGET_USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${TARGET_USERNAME}-nopasswd && \
    chmod 0440 /etc/sudoers.d/${TARGET_USERNAME}-nopasswd

    echo "Migration completed: $BUILD_USERNAME (uid:1000) -> $TARGET_USERNAME (uid:1000)"
else
    echo "Using existing user: $TARGET_USERNAME (uid:1000)"
fi
