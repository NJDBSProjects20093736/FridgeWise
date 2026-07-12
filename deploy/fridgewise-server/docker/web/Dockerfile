# FridgeWise Flutter web — multi-stage build (Linux)
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY app/pubspec.yaml app/pubspec.lock ./
RUN flutter pub get

COPY app/ .

# Optional override, e.g. https://your-domain.com/api
# Leave empty to use same-origin /api when served behind bundled nginx.
ARG API_BASE_URL=
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.27-alpine

COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
