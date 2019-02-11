# strongSwan VPN + Alpine Linux

[![Build Status](https://travis-ci.com/smockle/alpine-strongswan.svg?branch=master)](https://travis-ci.com/smockle/alpine-strongswan)
[![Docker Pulls](https://img.shields.io/docker/pulls/smockle/alpine-strongswan.svg?style=flat)](https://hub.docker.com/r/smockle/alpine-strongswan)

This is a fork of [stanback/alpine-strongswan-vpn](https://github.com/stanback/alpine-strongswan-vpn), a repository containing a Dockerfile for generating an image with [strongSwan](https://www.strongswan.org/) and [Alpine Linux](https://alpinelinux.org/).

This image can be used on the server or client in a variety of configurations.

The reference configuration in this repository and following guidelines are intended to provide an attempt at a best-practice example for setting up a universal VPN server with PEAP-EAP-TLS clients.

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

1. Double-click the CA certificate (`config/ipsec.d/cacerts/caCert.pem`) to import it into the keychain.

2. In the Keychain Access app, find the imported certificate, right-click it and select “Get Info”, then select “Trust”: “Always Trust” in the info dialog.

3. Double-click the p12 file (`config/ipsec.d/userCert.p12`) to import it into the keychain. When prompted, enter the password for the p12 file (use `docker logs strongswan` to find it).

4. Open System Preferences and click “Network” > “+”. Select “Interface”: “VPN” and “VPN Type”: “IKEv2” and click “Create”.

5. Select the new interface from the list and set the “Server Address” and “Remote ID” to the `$SERVER_CN` in the running container, then set “Local ID” to the `$USER_CN`.

6. Click “Authentication Settings…”, set “Authentication Settings” to “Certificate” and click “Select…” to specify the user certificate to use. Select the certificate named `$USER_CN` and signed by `$CA_CN`, then click “Ok”.

7. Click “Apply”, then “Connect” to save and test the connection.

## iOS 12

Crypto: IKEv2 AES256-SHA256-MODP2048

1. Send the CA certificate (`config/ipsec.d/cacerts/caCert.pem`) to the iOS device.

2. In the Settings app, tap “General”, then “Profiles & Device Management”, then the newly-added CA certificate, then “Install”. Input your passcode, then tap “Install” again, then tap “Done”.

3. Send the p12 file (`config/ipsec.d/userCert.p12`) to the iOS device.

4. In the Settings app, tap “General”, then “Profiles & Device Management”, then the newly-added CA certificate, then “Install”. Input your passcode, then tap “Install” again. When prompted, enter the password for the p12 file (use `docker logs strongswan` to find it), then tap “Done”.

5. In the Settings app, tap “General”, then “VPN”, then “Add VPN Configuration…”.

6. In the “Add Configuration” pane, select “Type”: “IKEv2”. Set “Description”, then set “Server” and “Remote ID” to the `$SERVER_CN` and “Local ID” to the `$USER_CN`.

7. Set “User Authentication” to “Certificate”, then select the “Certificate” installed in step 1.

# Additional Resources

- https://github.com/stanback/alpine-strongswan-vpn
- http://thomas.irmscher.bayern/crypto/VPN-with-Pi-StrongSwan-IKEv2-and-EAP-MSCHAPv2-for-Windows-Phone-8.1.html
- https://www.zeitgeist.se/2013/11/22/strongswan-howto-create-your-own-vpn/
- https://blog.arrogantrabbit.com/vpn/IKEv2-VPN-setup-on-Apline-Linux/
- https://gist.github.com/karlvr/34f46e1723a2118bb16190c22dbed1cc
