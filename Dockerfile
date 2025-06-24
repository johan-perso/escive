# syntax=docker/dockerfile:1

# Use a pre-built Flutter image
FROM ghcr.io/cirruslabs/flutter:3.29.0 AS build-env

# Check Flutter is installed
RUN flutter doctor -v

# Set the working directory
WORKDIR /app
COPY . .

# Build the Flutter app
RUN flutter clean
RUN flutter pub get
RUN flutter build web --release

# Serve the app using Nginx
FROM nginx:alpine AS production
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]