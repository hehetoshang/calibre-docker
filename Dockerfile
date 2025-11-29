FROM debian:12

ARG TARGETARCH
ARG TARGETVARIANT
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_BREAK_SYSTEM_PACKAGES=1

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

# 安装 Python 包（使用 --break-system-packages）
RUN pip3 install --no-cache-dir --break-system-packages \
    flask \
    sqlalchemy \
    requests \
    beautifulsoup4

# 根据架构安装 Calibre - 修复 ARMv7 安装问题
RUN if [ "$TARGETARCH" = "amd64" ] || [ "$TARGETARCH" = "arm64" ]; then \
        echo "Installing Calibre via apt for $TARGETARCH" && \
        apt-get update && \
        apt-get install -y calibre && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*; \
    elif [ "$TARGETARCH" = "arm" ] && [ "$TARGETVARIANT" = "v7" ]; then \
        echo "Installing Calibre for ARMv7 using official installer..." && \
        apt-get update && \
        apt-get install -y xz-utils python3 python3-pip libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 libxcb-xinerama0 libxcb-xfixes0 libxcb-shape0 libxcb-util1 && \
        # 使用官方安装脚本，但添加更多错误处理 \
        wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | \
            sh /dev/stdin install_dir=/usr || \
        (echo "Fallback: Trying alternative installation method" && \
         wget -O /tmp/calibre-installer.py https://download.calibre-ebook.com/linux-installer.py && \
         python3 /tmp/calibre-installer.py --install-dir=/usr --binary-depends) && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /tmp/calibre-installer-cache /tmp/calibre-installer.py; \
    else \
        echo "Unknown architecture: $TARGETARCH $TARGETVARIANT" && \
        exit 1; \
    fi

# 条件安装 PyQt5 - 对于 ARMv7 使用系统包
RUN if [ "$TARGETARCH" = "amd64" ] || [ "$TARGETARCH" = "arm64" ]; then \
        pip3 install --no-cache-dir --break-system-packages pyqt5; \
    elif [ "$TARGETARCH" = "arm" ] && [ "$TARGETVARIANT" = "v7" ]; then \
        echo "Installing PyQt5 via apt for ARMv7" && \
        apt-get update && \
        apt-get install -y python3-pyqt5 python3-pyqt5.qtwebengine && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# 验证 Calibre 安装
RUN echo "Verifying Calibre installation..." && \
    if command -v calibre > /dev/null 2>&1; then \
        echo "Calibre installed successfully" && \
        calibre --version; \
    else \
        echo "Calibre installation failed, trying alternative..." && \
        # 备用方案：使用 pip 安装 calibre-server \
        pip3 install --no-cache-dir --break-system-packages calibre-server || \
        (echo "All Calibre installation methods failed" && exit 1); \
    fi

# 创建应用用户
RUN useradd -m -u 1000 -s /bin/bash talebook && \
    mkdir -p /app /data && \
    chown talebook:talebook /app /data

USER talebook
WORKDIR /app

CMD ["/bin/bash"]