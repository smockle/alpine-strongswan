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

# Copy ipsec script and make it executable
COPY ipsec.sh /usr/local/bin/ipsec.sh
RUN chmod +x /usr/local/bin/ipsec.sh

# List ports which should be published
EXPOSE 500/udp 4500/udp

# Start IPSEC VPN server & client
ENTRYPOINT ["/usr/local/bin/ipsec.sh"]
CMD ["start", "--nofork"]