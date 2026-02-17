# Stage 1: Lấy link tải AionUi mới nhất
FROM curlimages/curl:latest AS fetcher
USER root
RUN apk add --no-cache jq
RUN curl -s https://api.github.com/repos/iOfficeAI/AionUi/releases/latest \
    | jq -r '.assets[].browser_download_url | select(contains("deb"))' > /tmp/urls.txt

# Stage 2: Cấu hình Debian + nvm + AionUi
FROM debian:stable

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
ENV NVM_DIR=/home/aionuser/.nvm
ENV NODE_VERSION=20.11.1

# 1. Cài đặt dependencies cơ bản, sudo và thư viện UI
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    ca-certificates \
    sudo \
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

# 2. Tạo user và cấp quyền sudo
RUN useradd -m -s /bin/bash aionuser && \
    usermod -aG sudo aionuser && \
    echo "aionuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER aionuser
WORKDIR /home/aionuser

# 3. Cài đặt nvm và Node.js
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

# Thêm nvm vào PATH để sử dụng node/npm trực tiếp
ENV PATH="/home/aionuser/.nvm/versions/node/v${NODE_VERSION}/bin:${PATH}"

# 4. Cài đặt AionUi bản mới nhất (Cần dùng sudo để cài file .deb)
COPY --from=fetcher /tmp/urls.txt /tmp/urls.txt
RUN set -ex; \
    ARCH_SUFFIX=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64"); \
    DOWNLOAD_URL=$(grep "$ARCH_SUFFIX" /tmp/urls.txt); \
    sudo wget -O /tmp/aionui.deb "$DOWNLOAD_URL" && \
    sudo apt-get update && \
    sudo apt-get install -y /tmp/aionui.deb && \
    sudo rm /tmp/aionui.deb && \
    sudo rm -rf /var/lib/apt/lists/*

# Cấu hình môi trường ứng dụng
ENV AIONUI_PORT=3000
ENV AIONUI_ALLOW_REMOTE=true

EXPOSE 3000

# Khởi chạy
ENTRYPOINT ["AionUi"]
CMD ["--no-sandbox", "--webui", "--remote", "--port", "3000"]
