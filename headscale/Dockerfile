FROM golang:1.24-bookworm AS source
ADD https://github.com/juanfont/headscale/tarball/main /tmp/headscale.tar.gz
RUN mkdir -p /app && \
    tar -xzf /tmp/headscale.tar.gz -C /app --strip-components=1 && \
    rm /tmp/headscale.tar.gz && \
    cd /app && \
    CGO_ENABLED=0 go build -o headscale ./cmd/headscale

FROM debian:bookworm-slim AS release
COPY --from=source --chmod=0755 /app/headscale /usr/local/bin/headscale
ENTRYPOINT [ "/usr/local/bin/headscale" ]