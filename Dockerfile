# Stage 1: Build binary
FROM dart:stable AS build

# Đặt thư mục làm việc
WORKDIR /app

# Kích hoạt dart_frog CLI
RUN dart pub global activate dart_frog_cli

# Copy package campus_core và backend để resolve dependencies
COPY packages/campus_core ./packages/campus_core
COPY backend ./backend

# Build production bundle từ backend
WORKDIR /app/backend
RUN dart pub get
RUN dart pub global run dart_frog_cli:dart_frog build

# Compile mã nguồn đã build thành file binary thực thi độc lập
WORKDIR /app/backend/build
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2: Runtime image siêu nhẹ
FROM subfuzion/dart:slim

WORKDIR /app
COPY --from=build /app/backend/build/bin/server /app/bin/server

# Expose cổng mặc định của Render (Render thường bind qua biến PORT, mặc định là 8080)
EXPOSE 8080

CMD ["/app/bin/server"]