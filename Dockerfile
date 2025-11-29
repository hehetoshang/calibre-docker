FROM debian:12

ARG TARGETARCH
ARG TARGETVARIANT
ENV DEBIAN_FRONTEND=noninteractive

# 安装基础系统
RUN apt-get update && \
    apt-get install -y \
        tzdata \
        python3 \
        python3-pip \
        python3-venv \
        nginx \
        supervisor \
        sqlite3 \
        curl \
        wget \
        unzip \
        git \
        ca-certificates \
        # Calibre 相关依赖
        python3-dateutil \
        python3-cssselect \
        python3-lxml \
        python3-pil \
        python3-psutil \
        python3-chardet \
        python3-html5lib \
        fonts-liberation && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 根据架构安装 Calibre
RUN if [ "$TARGETARCH" = "amd64" ] || [ "$TARGETARCH" = "arm64" ]; then \
        # x86_64 和 arm64 直接安装 calibre
        apt-get update && \
        apt-get install -y calibre && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*; \
    elif [ "$TARGETARCH" = "arm" ] && [ "$TARGETVARIANT" = "v7" ]; then \
        # ARM32 使用官方安装脚本
        apt-get update && \
        apt-get install -y xz-utils && \
        wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | \
            sh /dev/stdin install_dir=/usr && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /tmp/calibre-installer-cache; \
    fi

# 安装 Python 包
RUN pip3 install --no-cache-dir \
    flask \
    sqlalchemy \
    requests \
    beautifulsoup4

# 条件安装 PyQt5（在 ARM32 上可选）
RUN if [ "$TARGETARCH" != "arm" ] || [ "$TARGETVARIANT" != "v7" ]; then \
        pip3 install --no-cache-dir pyqt5; \
    else \
        echo "Skipping PyQt5 on ARM32 to avoid compatibility issues"; \
    fi

# 创建应用用户
RUN useradd -m -u 1000 -s /bin/bash talebook && \
    mkdir -p /app /data && \
    chown talebook:talebook /app /data

USER talebook
WORKDIR /app

CMD ["/bin/bash"]