# strongSwan VPN + Alpine Linux

This is a fork of [stanback/alpine-strongswan-vpn](https://github.com/stanback/alpine-strongswan-vpn), a repository containing a Dockerfile for generating an image with [strongSwan](https://www.strongswan.org/) and [Alpine Linux](https://alpinelinux.org/).

This image can be used on the server or client in a variety of configurations.

The reference configuration in this repository and following guidelines are intended to provide an attempt at a best-practice example for setting up a universal VPN server that with PEAP-EAP-TLS clients over IPv4 & IPv6.

# Setup

1. Download the following configuration files from https://github.com/smockle/alpine-strongswan.git:

- config/
  - config/ipsec.conf
  - config/ipsec.secrets
  - config/strongswan.conf
  - config/ipsec.d/firewall.updown

2. Edit the configuration files to your liking. You should change the secrets in `ipsec.secrets`, update `rightsourceip=` and `leftid=` in `ipsec.conf` to match your network setup, and review the rules in `ipsec.d/firewall.updown`.

3. If running behind a router, you'll need to forward ports 500/udp and 4500/udp. If you have a local firewall, you'll need to accept packets from ports 500/udp, 4500/udp, and possibly protocol 50 (ESP), and protocol 51 (AH).

4. For Docker hosts receiving their IP and gateway from router advertisements: Set `accept_ra=2` for your interface with sysctl or in `/etc/network/interfaces`, otherwise advertisements are disabled when IPv6 packet forwarding is enabled.

# Usage

When the container is run for the first time, a certificate signing authority, server and user (client) certificate is created automatically, if one is not present in your volume.

Running the Docker container typically requires running with elevated privileges including `--cap-add=NET_ADMIN` and `--net=host`. It will have permission to modify your Docker host's networking and iptables configuration.

Ensure the config folder is in your current directory (`$PWD`) and run:

```Bash
docker run -d \
    --cap-add=NET_ADMIN \
    --net=host \
    -e C="CH" \
    -e O="strongSwan" \
    -e CA_CN="strongSwan Root CA" \
    -e SERVER_CN="moon.strongswan.org" \
    -e USER_CN="carol@strongswan.org" \
    -e PUID=1000 \
    -e PGID=1000 \
    -v $PWD/config/strongswan.conf:/etc/strongswan.conf \
    -v $PWD/config/ipsec.conf:/etc/ipsec.conf \
    -v $PWD/config/ipsec.secrets:/etc/ipsec.secrets \
    -v $PWD/config/ipsec.d:/etc/ipsec.d \
    --name=strongswan \
    smockle/alpine-strongswan
```

You may need to enable packet forwarding and ndp proxying on your docker host via sysctl or /etc/sysctl.conf:

```
sudo sysctl net.ipv4.ip_forward=1
sudo sysctl net.ipv6.conf.all.forwarding=1
sudo sysctl net.ipv6.conf.all.proxy_ndp=1
sudo iptables -A FORWARD -j ACCEPT
```

# Debugging

You can append arguments like `start --nofork --debug` to get debug output. Run `--help` for list of arguments.

There are various ways to check on strongSwan, including tailing the Docker logging output (stdout/stderr), the `ipsec` command, and the `swanctl` command:

```Bash
docker logs -f --tail 100 strongswan
docker exec -it strongswan ipsec statusall
docker exec -it strongswan swanctl --list-sas
```

# Developing

```Bash
# Build and run, without tags, then clean
docker run --rm -it $(docker build -q .)

# Build and run, with tags, without cleaning
docker build -t alpine-strongswan-devel . && docker run -it alpine-strongswan-devel

# Shell in running container
docker exec -it $(docker ps -q) sh
```

# Using the VPN

## macOS 10.14 Mojave

Crypto: IKEv2 AES256-SHA256-MODP2048

On macOS, you'll need to import and trust the CA certificate (`config/ipsec.d/cacerts/caCert.pem`), the user certificate (`config/ipsec.d/certs/userCert.pem`), and the exported .p12 file (`config/ipsec.d/userCert.p12`). When asked to specify authentication type, select “Certificate”.

## iOS 12

Crypto: IKEv2 AES256-SHA256-MODP2048

To setup, go to Settings -> General -> VPN. Add a new VPN configuration with type "IKEv2". Enter a description, server, remote ID, and local ID. Local ID should typically be your username. For authentication, “Certificate”.

# Additional Resources

- https://github.com/stanback/alpine-strongswan-vpn
- http://thomas.irmscher.bayern/crypto/VPN-with-Pi-StrongSwan-IKEv2-and-EAP-MSCHAPv2-for-Windows-Phone-8.1.html
- https://www.zeitgeist.se/2013/11/22/strongswan-howto-create-your-own-vpn/
- https://blog.arrogantrabbit.com/vpn/IKEv2-VPN-setup-on-Apline-Linux/
