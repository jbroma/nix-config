# Pi coding agent in a throwaway Linux VM (Apple container). Built by the pi-sandbox command,
# which tags the image by this directory's store hash: bump the Pi version here to rebuild.
FROM node:24-bookworm-slim
# Tools for the agent's own work inside the sandbox (python3 and a compiler included); this layer
# is reused when only the Pi version below changes.
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       git ripgrep fd-find jq curl ca-certificates python3 build-essential \
  && rm -rf /var/lib/apt/lists/* \
  && ln -s /usr/bin/fdfind /usr/local/bin/fd
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@0.84.3
COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint
WORKDIR /workspace
ENTRYPOINT ["entrypoint"]
