FROM ruby:2.7-alpine AS base

ENV APP_DIR="/srv/app" \
    BUNDLE_PATH="/srv/bundler" \
    BUILD_PACKAGES="build-base ruby-dev" \
    APP_PACKAGES="bash tzdata shared-mime-info" \
    APP_USER="app"

# Thes env var definitions reference values from the previous definitions, so
# they need to be split off on their own. Otherwise, they'll receive stale
# values because Docker will read the values once before it starts setting
# values.
ENV BUNDLE_BIN="${BUNDLE_PATH}/bin" \
    GEM_HOME="${BUNDLE_PATH}" \
    RELEASE_PACKAGES="${APP_PACKAGES}"
ENV PATH="${APP_DIR}:${BUNDLE_BIN}:${PATH}"

RUN mkdir -p $APP_DIR $BUNDLE_PATH
WORKDIR $APP_DIR

FROM base as build

RUN apk --update upgrade && \
  apk add \
    --virtual app \
    $APP_PACKAGES && \
  apk add \
    --virtual build_deps \
    $BUILD_PACKAGES

COPY Gemfile* $APP_DIR/
RUN bundle config set deployment 'true' && \
    bundle config set without 'development test' && \
    bundle install --jobs=4

COPY . $APP_DIR/

FROM base AS release

RUN apk --update upgrade && \
  apk add \
    --virtual app \
    $RELEASE_PACKAGES && \
  rm -rf /var/cache/apk/*

RUN wget -qO- https://github.com/cloudtruth/cloudtruth-cli/releases/latest/download/install.sh |  sh

COPY --from=build $BUNDLE_PATH $BUNDLE_PATH
COPY --from=build $APP_DIR $APP_DIR

ENTRYPOINT ["bundle", "exec", "exe/cloudtruth-importer"]
CMD ["--help"]
