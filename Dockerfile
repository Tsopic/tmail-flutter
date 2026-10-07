ARG FLUTTER_VERSION=3.38.9
ARG APP_VERSION

# Stage 1 - Install dependencies and build the app
# This matches the flutter version on our CI/CD pipeline on Github
FROM --platform=amd64 ghcr.io/instrumentisto/flutter:${FLUTTER_VERSION} AS build-env

# Pass version into build stage
ARG APP_VERSION
ARG SENTRY_AUTH_TOKEN
ARG SENTRY_ORG
ARG SENTRY_PROJECT
ARG SENTRY_URL
ARG SENTRY_RELEASE
ARG VCS_REF
ARG GITHUB_SHA

# Set directory to Copy App
WORKDIR /app
COPY . .

ENV GITHUB_SHA=$GITHUB_SHA \
    SENTRY_ORG=$SENTRY_ORG \
    SENTRY_PROJECT=$SENTRY_PROJECT \
    SENTRY_URL=$SENTRY_URL \
    SENTRY_RELEASE=$SENTRY_RELEASE

RUN ./scripts/prebuild.sh && \
    SENTRY_AUTH_TOKEN=${SENTRY_AUTH_TOKEN:-} ./scripts/configure-sentry.sh && \
    if [ -n "$APP_VERSION" ]; then \
      flutter build web --release --source-maps --no-web-resources-cdn \
        --dart-define=SENTRY_RELEASE=$SENTRY_RELEASE --dart-define=SENTRY_DIST=$GITHUB_SHA \
        --build-name="$APP_VERSION"; \
    else \
      flutter build web --release --source-maps --no-web-resources-cdn \
        --dart-define=SENTRY_RELEASE=$SENTRY_RELEASE --dart-define=SENTRY_DIST=$GITHUB_SHA; \
    fi && \
    SENTRY_AUTH_TOKEN=${SENTRY_AUTH_TOKEN:-} ./scripts/run-sentry.sh

FROM nginx:alpine
RUN apk add gzip
COPY --from=build-env /app/server/nginx.conf /etc/nginx
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD gzip -k -r -f /usr/share/nginx/html/ && nginx -g 'daemon off;'
