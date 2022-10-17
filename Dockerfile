
# bump: twolame /TWOLAME_VERSION=([\d.]+)/ https://github.com/njh/twolame.git|*
# bump: twolame after ./hashupdate Dockerfile TWOLAME $LATEST
# bump: twolame link "Source diff $CURRENT..$LATEST" https://github.com/njh/twolame/compare/v$CURRENT..v$LATEST
ARG TWOLAME_VERSION=0.4.0
ARG TWOLAME_URL="https://github.com/njh/twolame/releases/download/$TWOLAME_VERSION/twolame-$TWOLAME_VERSION.tar.gz"
ARG TWOLAME_SHA256=cc35424f6019a88c6f52570b63e1baf50f62963a3eac52a03a800bb070d7c87d

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG TWOLAME_URL
ARG TWOLAME_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O twolame.tar.gz "$TWOLAME_URL" && \
  echo "$TWOLAME_SHA256  twolame.tar.gz" | sha256sum --status -c - && \
  mkdir twolame && \
  tar xf twolame.tar.gz -C twolame --strip-components=1 && \
  rm twolame.tar.gz && \
  apk del download

FROM base AS build 
COPY --from=download /tmp/twolame/ /tmp/twolame/
WORKDIR /tmp/twolame
RUN \
  apk add --no-cache --virtual build \
    build-base pkgconf && \
  ./configure --disable-shared --enable-static --disable-sndfile --with-pic && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path twolame && \
  ar -t /usr/local/lib/libtwolame.a && \
  readelf -h /usr/local/lib/libtwolame.a && \
  # Cleanup
  apk del build

FROM scratch
ARG TWOLAME_VERSION
COPY --from=build /usr/local/lib/pkgconfig/twolame.pc /usr/local/lib/pkgconfig/twolame.pc
COPY --from=build /usr/local/lib/libtwolame.a /usr/local/lib/libtwolame.a
COPY --from=build /usr/local/include/twolame.h /usr/local/include/twolame.h
