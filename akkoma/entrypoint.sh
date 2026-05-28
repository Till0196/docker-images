#!/bin/sh

set -eu

: "${AKKOMADIR:=/akkoma}"
: "${AKKOMA_DEFAULT_CONFIG_PATH:=/etc/akkoma/config.exs}"
: "${PLEROMA_CONFIG_PATH:=${AKKOMA_CONFIG_PATH:-$AKKOMA_DEFAULT_CONFIG_PATH}}"
: "${AKKOMA_CONFIG_PATH:=$PLEROMA_CONFIG_PATH}"
: "${AKKOMA_DB_PATH:=$AKKOMADIR/config/setup_db.psql}"
: "${AKKOMA_STATIC_DIR:=$AKKOMADIR/static}"
: "${AKKOMA_UPLOADS_DIR:=$AKKOMADIR/uploads}"
: "${AKKOMA_FRONTEND_NAME:=soapbox}"
: "${AKKOMA_FRONTEND_REF:=main}"
: "${AKKOMA_FRONTEND_ROOT:=$AKKOMA_STATIC_DIR/frontends/$AKKOMA_FRONTEND_NAME/$AKKOMA_FRONTEND_REF}"
: "${AKKOMA_ENABLE_CADDY:=true}"
: "${AKKOMA_UPSTREAM:=127.0.0.1:4000}"
: "${CADDY_CONFIG:=/etc/caddy/Caddyfile}"
: "${CADDY_LISTEN:=:8080}"
: "${AKKOMA_RUNTIME_CONFIG_DIR:=/tmp/akkoma-config}"
: "${AKKOMA_GENERATE_CONFIG:=false}"
: "${AKKOMA_RUN_DB_SETUP:=true}"
: "${AKKOMA_RUN_MIGRATIONS:=true}"
: "${DB_PORT:=5432}"

AKKOMA_CONFIG_PATH="$PLEROMA_CONFIG_PATH"
export AKKOMA_CONFIG_PATH
export PLEROMA_CONFIG_PATH="$AKKOMA_CONFIG_PATH"
export AKKOMA_FRONTEND_ROOT AKKOMA_STATIC_DIR AKKOMA_UPSTREAM CADDY_LISTEN

dbwait() {
	echo "-- Waiting for database..."
	while ! pg_isready -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -t 1; do
		sleep 1s
	done
}

seed_static() {
	if [ ! -d "$AKKOMADIR/static.dist" ]; then
		return
	fi

	mkdir -p "$AKKOMA_STATIC_DIR"
	for static_item in "$AKKOMADIR"/static.dist/*; do
		[ -e "$static_item" ] || continue
		name="$(basename "$static_item")"
		if [ "$name" = "frontends" ]; then
			continue
		fi
		if [ ! -e "$AKKOMA_STATIC_DIR/$name" ]; then
			cp -a "$static_item" "$AKKOMA_STATIC_DIR/"
		fi
	done

	[ -d "$AKKOMADIR/static.dist/frontends" ] || return
	mkdir -p "$AKKOMA_STATIC_DIR/frontends"
	for frontend in "$AKKOMADIR"/static.dist/frontends/*; do
		[ -d "$frontend" ] || continue
		name="$(basename "$frontend")"
		if [ ! -d "$AKKOMA_STATIC_DIR/frontends/$name" ]; then
			cp -a "$frontend" "$AKKOMA_STATIC_DIR/frontends/"
		fi
	done
}

remove_static_fallback_index() {
	if [ ! -f "$AKKOMA_STATIC_DIR/index.html" ]; then
		return
	fi

	if [ ! -f "$AKKOMA_FRONTEND_ROOT/index.html" ]; then
		return
	fi

	echo "-- Removing static fallback index.html so $AKKOMA_FRONTEND_NAME/$AKKOMA_FRONTEND_REF can serve / --"
	rm "$AKKOMA_STATIC_DIR/index.html"
}

start_akkoma() {
	echo "-- Starting Akkoma!"
	"$AKKOMADIR/bin/pleroma" start
}

start_caddy() {
	echo "-- Starting Caddy on $CADDY_LISTEN..."
	caddy run --config "$CADDY_CONFIG" --adapter caddyfile &
	CADDY_PID=$!
}

stop_background_services() {
	if [ -n "${CADDY_PID:-}" ]; then
		caddy stop --config "$CADDY_CONFIG" >/dev/null 2>&1 || kill "$CADDY_PID" >/dev/null 2>&1 || true
	fi
}

secure_config_path() {
	[ -f "$AKKOMA_CONFIG_PATH" ] || return

	mode="$(stat -c '%a' "$AKKOMA_CONFIG_PATH")"
	other_perms="${mode#${mode%?}}"
	if [ "$other_perms" = "0" ]; then
		return
	fi

	echo "-- Config has world permissions; copying to a private runtime path --"
	mkdir -p "$AKKOMA_RUNTIME_CONFIG_DIR"
	cp "$AKKOMA_CONFIG_PATH" "$AKKOMA_RUNTIME_CONFIG_DIR/config.exs"
	chmod 0640 "$AKKOMA_RUNTIME_CONFIG_DIR/config.exs"
	AKKOMA_CONFIG_PATH="$AKKOMA_RUNTIME_CONFIG_DIR/config.exs"
	PLEROMA_CONFIG_PATH="$AKKOMA_CONFIG_PATH"
	export AKKOMA_CONFIG_PATH PLEROMA_CONFIG_PATH
}

seed_static
remove_static_fallback_index

if [ ! -f "$AKKOMA_CONFIG_PATH" ] && [ "$AKKOMA_GENERATE_CONFIG" = "true" ]; then
	echo "-- Generating instance configuration --"
	mkdir -p "$(dirname "$AKKOMA_CONFIG_PATH")"
	"$AKKOMADIR/bin/pleroma_ctl" instance gen \
		--output "$AKKOMA_CONFIG_PATH" \
		--output-psql "$AKKOMA_DB_PATH" \
		--domain "$INSTANCE_DOMAIN" \
		--instance-name "$INSTANCE_NAME" \
		--media-url "$MEDIA_URL" \
		--admin-email "$INSTANCE_ADMIN_EMAIL" \
		--notify-email "$INSTANCE_NOTIFY_EMAIL" \
		--dbhost "$DB_HOST" \
		--dbname "$DB_NAME" \
		--dbuser "$DB_USER" \
		--dbpass "$DB_PASS" \
		--rum N \
		--indexable "$INSTANCE_INDEX" \
		--db-configurable "$INSTANCE_ADMINFE" \
		--uploads-dir "$AKKOMA_UPLOADS_DIR" \
		--static-dir "$AKKOMA_STATIC_DIR" \
		--listen-ip "0.0.0.0" \
		--listen-port "4000" \
		--strip-uploads-metadata "$STRIP_UPLOADS" \
		--anonymize-uploads "$ANONYMIZE_UPLOADS" \
		--read-uploads-description "$READ_UPLOAD_DATA"
	echo "-- Generated instance config --"
elif [ ! -f "$AKKOMA_CONFIG_PATH" ]; then
	echo "-- Config file not found: $AKKOMA_CONFIG_PATH --"
	echo "-- Set AKKOMA_CONFIG_PATH to an existing file or set AKKOMA_GENERATE_CONFIG=true --"
	exit 1
fi

secure_config_path

if [ "$AKKOMA_RUN_DB_SETUP" = "true" ] && [ -f "$AKKOMA_DB_PATH" ]; then
	echo "-- Initializing database --"
	dbwait
	PGPASSWORD="$DB_PASS" psql \
		-h "$DB_HOST" \
		-p "$DB_PORT" \
		-U "$DB_USER" \
		-f "$AKKOMA_DB_PATH" \
		"$DB_NAME"
	rm "$AKKOMA_DB_PATH"

	echo "-- Initialized database --"
fi

dbwait

if [ "$AKKOMA_RUN_MIGRATIONS" = "true" ]; then
	echo "-- Running migrations..."
	"$AKKOMADIR/bin/pleroma_ctl" migrate
fi

if [ "$AKKOMA_ENABLE_CADDY" != "true" ]; then
	start_akkoma
	exit $?
fi

start_caddy
trap 'stop_background_services' INT TERM EXIT

start_akkoma &
AKKOMA_PID=$!
wait "$AKKOMA_PID"
