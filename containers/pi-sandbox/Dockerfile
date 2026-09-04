# Pi coding agent in a throwaway Linux VM (Apple container). Built by the pi-sandbox command,
# which tags the image by this directory's store hash: bump the Pi version here to rebuild.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@0.84.3
COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint
WORKDIR /workspace
ENTRYPOINT ["entrypoint"]
