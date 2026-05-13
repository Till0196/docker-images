FROM hexpm/elixir:1.19.5-erlang-28.5-alpine-3.23.4 AS otp
ARG MIX_ENV="prod"
ARG TMPDIR="/tmp/akkoma"
ARG BUILD_TAG="v3.19.0"
ARG PLEROMA_BUILD_BRANCH=${BUILD_TAG}
# install dependencies
RUN apk add --no-cache git gcc g++ musl-dev make cmake file-dev rclone wget zip imagemagick
# get source
RUN git clone --depth 1 --branch ${BUILD_TAG} https://akkoma.dev/AkkomaGang/akkoma.git ${TMPDIR}
WORKDIR ${TMPDIR}
# clean
RUN (rm -rf release || true) && (rm -rf _build || true) && (rm -rf /root/.mix)
# setup-hex
RUN mix local.hex --force && mix local.rebar --force
# mix-clean
RUN mix deps.clean --all && mix clean
RUN mix deps.get --only prod
RUN mix release --path $TMPDIR/release

FROM alpine:3.23.4 AS soapbox-frontend
ARG SOAPBOX_REF="main"
ARG SOAPBOX_BUILD_URL=""
RUN apk add --no-cache ca-certificates curl unzip
RUN set -eux; \
    build_url="${SOAPBOX_BUILD_URL:-https://gitlab.com/soapbox-pub/soapbox/-/jobs/artifacts/${SOAPBOX_REF}/raw/soapbox.zip?job=build}"; \
    mkdir -p /static.dist/frontends/soapbox/${SOAPBOX_REF}; \
    curl -fsSL -o /tmp/soapbox.zip "${build_url}"; \
    unzip -q /tmp/soapbox.zip -d /static.dist/frontends/soapbox/${SOAPBOX_REF}; \
    rm /tmp/soapbox.zip

FROM alpine:3.23.4 AS akkoma-basic-alpine
ARG AKKOMADIR="/akkoma"
ARG TMPDIR="/tmp/akkoma"
ARG SOAPBOX_REF="main"
COPY --from=otp ${TMPDIR}/release ${AKKOMADIR}
COPY --from=otp ${TMPDIR}/priv/static ${AKKOMADIR}/static.dist
COPY --from=soapbox-frontend /static.dist ${AKKOMADIR}/static.dist
# dependencies
RUN apk add --no-cache caddy postgresql-client
# optional dependencies
RUN apk add --no-cache imagemagick ffmpeg exiftool libsoup libmagic

WORKDIR ${AKKOMADIR}
EXPOSE 4000 8080
ENV AKKOMADIR=${AKKOMADIR}
ENV AKKOMA_STATIC_DIR=${AKKOMADIR}/static
ENV AKKOMA_UPLOADS_DIR=${AKKOMADIR}/uploads
ENV AKKOMA_FRONTEND_NAME=soapbox
ENV AKKOMA_FRONTEND_REF=${SOAPBOX_REF}
ENV AKKOMA_ENABLE_CADDY=true
ENV AKKOMA_UPSTREAM=127.0.0.1:4000
ENV CADDY_CONFIG=/etc/caddy/Caddyfile
ENV CADDY_LISTEN=:8080
ENV AKKOMA_CONFIGURABLE_FROM_DATABASE=false
ENV AKKOMA_GENERATE_CONFIG=false
ENV AKKOMA_RUN_DB_SETUP=true
ENV AKKOMA_RUN_MIGRATIONS=true
ENV DB_USER=postgres
ENV DB_HOST=db
ENV DB_NAME=${DB_USER}
ENV DB_PASS=postgres
ENV DB_PORT=5432
ENV INSTANCE_DOMAIN=akkoma.example.com
ENV MEDIA_URL=https://akkoma.example.com/media
ENV INSTANCE_NAME=Akkoma
ENV INSTANCE_ADMIN_EMAIL=admin@example.com
ENV INSTANCE_NOTIFY_EMAIL=info@example.com
# allow search engines to index site
# one of [y,n]
ENV INSTANCE_INDEX=y
# enables configuration via AdminFE
# one of [y,n]
ENV INSTANCE_ADMINFE=y
# one of [y,n]
ENV STRIP_UPLOADS=y
# one of [y,n]
ENV ANONYMIZE_UPLOADS=n
# one of [y,n]
ENV DEDUPLICATE_UPLOADS=n
# one of [y,n]
ENV READ_UPLOAD_DATA=y

COPY Caddyfile /etc/caddy/Caddyfile
COPY config.exs /etc/akkoma/config.exs
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
