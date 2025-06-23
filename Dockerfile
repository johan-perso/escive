# syntax=docker/dockerfile:1

# 1) Install Flutter
FROM ubuntu:20.04 AS build-env
LABEL stage=builder

## Update and install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl git unzip xz-utils libglu1-mesa libstdc++6 fontconfig libfreetype6 && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/*

## Define the required Flutter version
ARG FLUTTER_VERSION=3.29.0
ENV FLUTTER_ROOT=/usr/local/flutter
ENV PATH="$FLUTTER_ROOT/bin:$FLUTTER_ROOT/bin/cache/dart-sdk/bin:$PATH"

## Install Flutter SDK
ARG FLUTTER_VERSION=3.29.0
RUN curl -fSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz \
    -o flutter_linux_${FLUTTER_VERSION}-stable.tar.xz
RUN tar xf flutter_linux_${FLUTTER_VERSION}-stable.tar.xz -C /usr/local
RUN rm flutter_linux_${FLUTTER_VERSION}-stable.tar.xz
RUN chown -R 1000:1000 /usr/local/flutter

## Change current user (avoid being in root)
RUN useradd -m builder
USER builder
WORKDIR /home/builder

## Check Flutter installation is successful
RUN flutter doctor -v

# 2) Build the Flutter app
WORKDIR /app
COPY --chown=builder:builder . /app
RUN flutter clean
RUN flutter pub get
RUN flutter build web --release

# 3) Serve the app using Nginx
FROM nginx:alpine AS production
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]