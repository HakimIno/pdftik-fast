# Build stage
FROM debian:bullseye-slim as builder

# Install Zig and dependencies
RUN apt-get update && apt-get install -y \
    wget \
    xz-utils \
    && wget https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz \
    && tar -xf zig-linux-x86_64-0.11.0.tar.xz \
    && mv zig-linux-x86_64-0.11.0 /usr/local/zig

# Set Zig path
ENV PATH="/usr/local/zig:${PATH}"

# Copy source files
WORKDIR /build
COPY . .

# Build library
RUN zig build -Doptimize=ReleaseFast

# Final stage
FROM node:18-slim

# Install wkhtmltopdf
RUN apt-get update && apt-get install -y \
    wkhtmltopdf \
    && rm -rf /var/lib/apt/lists/*

# Copy built library
COPY --from=builder /build/zig-out/lib/libpdfgen.so /usr/local/lib/
COPY package.json index.js ./

# Install Node.js dependencies
RUN npm install ffi-napi

WORKDIR /app