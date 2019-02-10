#!/bin/sh
set -eo pipefail

# using $C, $O, $CA_CN, $SERVER_CN, $USER_CN
create_certs() {
  # Create IPSEC cofiguration directories
  sudo mkdir -p \
    /etc/ipsec.d/private \
    /etc/ipsec.d/cacerts \
    /etc/ipsec.d/certs \
    /etc/ipsec.d/aacerts \
    /etc/ipsec.d/ocspcerts \
    /etc/ipsec.d/acerts \
    /etc/ipsec.d/crls

  # CA: Create private key
  sudo ipsec pki --gen --type rsa --size 4096 \
    --outform pem | sudo tee /etc/ipsec.d/private/caKey.pem
  sudo chmod 600 /etc/ipsec.d/private/caKey.pem

  # CA: Create self-signed root certificate, using private key
  sudo ipsec pki --self --ca --lifetime 3650 \
    --in /etc/ipsec.d/private/caKey.pem --type rsa \
    --dn "C=$C, O=$O, CN=$CA_CN" \
    --outform pem | sudo tee /etc/ipsec.d/cacerts/caCert.pem

  # Server: Create private key
  sudo ipsec pki --gen --type rsa --size 2048 \
    --outform pem | sudo tee /etc/ipsec.d/private/serverKey.pem  
  sudo chmod 600 /etc/ipsec.d/private/serverKey.pem

  # Server: Create CA-signed certificate, using private keys
  sudo ipsec pki --issue --lifetime 1095 \
    --in /etc/ipsec.d/private/serverKey.pem --type priv \
    --cacert /etc/ipsec.d/cacerts/caCert.pem \
    --cakey /etc/ipsec.d/private/caKey.pem \
    --dn "C=$C, O=$O, CN=$SERVER_CN" \
    --san="$SERVER_CN" \
    --flag serverAuth --flag ikeIntermediate \
    --outform pem | sudo tee /etc/ipsec.d/certs/serverCert.pem

  # User: Create a private key
  sudo ipsec pki --gen --type rsa --size 2048 \
    --outform pem | sudo tee /etc/ipsec.d/private/userKey.pem
  sudo chmod 600 /etc/ipsec.d/private/userKey.pem

  # User: Create CA-signed certificate, using private keys
  sudo ipsec pki --issue --lifetime 1095 \
    --in /etc/ipsec.d/private/userKey.pem --type priv \
    --cacert /etc/ipsec.d/cacerts/caCert.pem \
    --cakey /etc/ipsec.d/private/caKey.pem \
    --dn "C=$C, O=$O, CN=$USER_CN" \
    --san="$USER_CN" \
    --outform pem | sudo tee /etc/ipsec.d/certs/userCert.pem

  # User: Merge private key & certificate into p12 binary file
  USER_PASS=$(date +%s | sha256sum | base64 | head -c 32; echo)
  sudo openssl pkcs12 -export \
    -inkey /etc/ipsec.d/private/userKey.pem \
    -in /etc/ipsec.d/certs/userCert.pem \
    -name "$USER_CN" \
    -certfile /etc/ipsec.d/cacerts/caCert.pem \
    -caname "$CA_CN" \
    -out /etc/ipsec.d/userCert.p12 \
    -passout pass:"$USER_PASS"
  echo "p12 binary file generated for '${USER_CN}' with password '${USER_PASS}'"
}

# Create certificates if they don’t already exist
[ ! -f /etc/ipsec.d/userCert.p12 ] && create_certs
unset create_certs

# Replace environment variables in ipsec.conf
eval "sudo tee /etc/ipsec.conf << EOF
$(cat < /etc/ipsec.conf)
EOF
" 2>/dev/null

# Fix volume permissions
sudo chown docker:docker /etc/strongswan.conf
sudo chown docker:docker /etc/ipsec.conf
sudo chown docker:docker /etc/ipsec.secrets
sudo chown -R docker:docker /etc/ipsec.d

# Pass arguments through to ipsec
sudo ipsec "$@"
