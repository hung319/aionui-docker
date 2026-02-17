# Stage 1: Lấy link tải AionUi mới nhất
FROM curlimages/curl:latest AS fetcher
USER root
RUN apk add --no-cache jq && \
    curl -s https://api.github.com/repos/iOfficeAI/AionUi/releases/latest \
    | jq -r '.assets[].browser_download_url | select(contains("deb"))' > /tmp/urls.txt

# Stage 2: Cấu hình trên Debian Stable Slim
FROM debian:stable-slim

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

# 1. Cài đặt Node.js, NPM và các công cụ từ repo mặc định của Debian
RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    npm \
    curl \
    wget \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 2. Cài đặt AionUi và tự động xử lý các thư viện phụ thuộc (dependencies)
COPY --from=fetcher /tmp/urls.txt /tmp/urls.txt
RUN set -ex; \
    ARCH_SUFFIX=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64"); \
    DOWNLOAD_URL=$(grep "$ARCH_SUFFIX" /tmp/urls.txt); \
    echo "Downloading AionUi from: $DOWNLOAD_URL"; \
    wget -O /tmp/aionui.deb "$DOWNLOAD_URL" && \
    apt-get update && \
    # Cài đặt file .deb và tự động tải các thư viện UI còn thiếu (libgtk, libnss, etc.)
    apt-get install -y /tmp/aionui.deb || apt-get install -y -f && \
    rm /tmp/aionui.deb && \
    rm -rf /var/lib/apt/lists/*

# 3. Cấu hình môi trường chạy
WORKDIR /root/app
ENV AIONUI_PORT=3000
ENV AIONUI_ALLOW_REMOTE=true

EXPOSE 3000

# Khởi chạy quyền root (bắt buộc --no-sandbox)
ENTRYPOINT ["AionUi"]
CMD ["--no-sandbox", "--webui", "--remote", "--port", "3000"]
