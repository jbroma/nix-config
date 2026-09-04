FROM node:24-bookworm-slim
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       git ripgrep fd-find jq curl ca-certificates python3 build-essential \
  && rm -rf /var/lib/apt/lists/* \
  && ln -s /usr/bin/fdfind /usr/local/bin/fd
WORKDIR /workspace
