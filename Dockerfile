# Stage 1: Lấy link tải AionUi mới nhất
FROM curlimages/curl:latest AS fetcher
USER root
RUN apk add --no-cache jq && \
    curl -s https://api.github.com/repos/iOfficeAI/AionUi/releases/latest \
    | jq -r '.assets[].browser_download_url | select(contains("deb"))' > /tmp/urls.txt

# Stage 2: Cấu hình Debian Stable + NVM + AionUi (All Root)
FROM debian:stable

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
ENV NVM_DIR=/root/.nvm
ENV NODE_VERSION=20.11.1

# 1. Cài đặt dependencies hệ thống và thư viện UI
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    ca-certificates \
    git \
    libgtk-3-0 \
    libnss3 \
    libasound2 \
    libgbm1 \
    libxshmfence1 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libatk1.0-0 \
    libcups2 \
    && rm -rf /var/lib/apt/lists/*

# 2. Cài đặt nvm và Node.js cho root
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

# Thêm Node.js vào PATH
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin:${PATH}"

# 3. Tải và cài đặt AionUi bản mới nhất
COPY --from=fetcher /tmp/urls.txt /tmp/urls.txt
RUN set -ex; \
    ARCH_SUFFIX=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64"); \
    DOWNLOAD_URL=$(grep "$ARCH_SUFFIX" /tmp/urls.txt); \
    echo "Installing AionUi for $ARCH_SUFFIX from $DOWNLOAD_URL"; \
    wget -O /tmp/aionui.deb "$DOWNLOAD_URL" && \
    apt-get update && \
    apt-get install -y /tmp/aionui.deb && \
    rm /tmp/aionui.deb && \
    rm -rf /var/lib/apt/lists/*

# 4. Cấu hình môi trường WebUI
WORKDIR /root/app
ENV AIONUI_PORT=3000
ENV AIONUI_ALLOW_REMOTE=true

EXPOSE 3000

# Khởi chạy trực tiếp (Root không cần sudo)
ENTRYPOINT ["AionUi"]
# Lưu ý: --no-sandbox là bắt buộc khi chạy quyền root trong container
CMD ["--no-sandbox", "--webui", "--remote", "--port", "3000"]
