ARG ARCH="amd64"
FROM multiarch/alpine:$ARCH-edge

# Install dependencies
RUN apk add --no-cache openssl strongswan

# Set default environment variables
ENV C "CH"
ENV O "strongSwan"
ENV CN "strongSwan Root CA"
ENV SERVER_CN "moon.strongswan.org"
ENV USER_CN "carol@strongswan.org"
ENV PUID 1000
ENV PGID 1000

# Copy ipsec script and make it executable
COPY ipsec.sh /usr/local/bin/ipsec.sh
RUN chmod +x /usr/local/bin/ipsec.sh

# List ports which should be published
EXPOSE 500/udp 4500/udp

# Create docker user & group
RUN apk add --no-cache shadow sudo && \
  if [ -z "$(getent group "${PGID}")" ]; then \
  addgroup -S -g "${PGID}" docker; \
  else \
  groupmod -n docker "$(getent group "${PGID}" | cut -d: -f1)"; \
  fi && \
  if [ -z "$(getent passwd "${PUID}")" ]; then \
  adduser -S -u "${PUID}" -G docker -s /bin/sh docker; \
  else \
  usermod -l docker -g "${PGID}" -d /home/docker -m "$(getent passwd "${PUID}" | cut -d: -f1)"; \
  fi && \
  echo "docker ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/docker && \
  chmod 0440 /etc/sudoers.d/docker
USER docker:docker

# Start IPSEC VPN server & client
ENTRYPOINT ["/usr/local/bin/ipsec.sh"]
CMD ["start", "--nofork"]