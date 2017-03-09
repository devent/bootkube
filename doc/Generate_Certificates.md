# Generate Certificates

This document describes how to generate self signed certificates with OpenSSL
for the Etcd cluster. Generate the CA certificate. The variable `ETCD_SAN`
must contain the etcd node advertise client URLs IP addresses and DNS names.
The tool `pwgen` can be used to generate a secure passphrase for the
private keys.

## Setup OpenSSL

First, we need to setup a directory structure and create an 
empty `index.txt` file, and the OpenSSL configuration file `openssl.conf`
(see below).

```
mkdir certs csr crl newcerts private passwords
touch index.txt
```

## Create CA

We need to set the following variables and the OpenSSL configuration
file `openssl.conf` needs to be updated to the organization. First, we need
to create the Certificate Authority (CA) that will sign the server and client
certificates. In addition, we need also remove the pass phrase from the
private key of the certificates, because Etcd can not ask for the pass phrase.

```
export CERT_DAYS=375
export KEY_SIZE=4096
export ETCD_SAN=IP:127.0.0.1,IP:172.31.0.101
openssl genrsa -aes256 -out private/ca_key.pem $KEY_SIZE
openssl rsa -in private/ca_key.pem -out private/ca_key_insecure.pem
openssl req -config ./openssl.cnf -key private/ca_key.pem -new -x509 -days $CERT_DAYS -sha256 -extensions v3_ca -out certs/ca.pem
```

* certs/ca.pem
* private/ca_key.pem
* private/ca_key_insecure.pem

## Create Server Certificates

Generate the TLS key and certificate. Only the insecure certificate key can 
be used. That will generate the following files. The variable `ETCD_SAN`
must contain all IP addresses of the Etcd node for which we create the
server certificate.

```
export CERT_DAYS=375
export KEY_SIZE=4096
export ETCD_SAN=IP:127.0.0.1,IP:172.31.0.101
openssl genrsa -aes256 -out private/etcd_key.pem $KEY_SIZE
openssl rsa -in etcd_key.pem -out private/etcd_key_insecure.pem
openssl req -config ./openssl.cnf -key private/etcd_key_insecure.pem -new -sha256 -out csr/etcd.csr
openssl ca -config ./openssl.cnf -create_serial -extensions etcd_server -days $CERT_DAYS -notext -md sha256 -in csr/etcd.csr -out certs/etcd.pem
```

* private/etcd_key.pem
* private/etcd_key_insecure.pem
* certs/etcd.pem

## Create Client Certificates

In similar fashion we can create the client certificate.

```
export CERT_DAYS=375
export KEY_SIZE=4096
openssl genrsa -aes256 -out private/client_key.pem $KEY_SIZE
openssl rsa -in private/client_key.pem -out private/client_key_insecure.pem
openssl req -config ./openssl.cnf -key private/client_key_insecure.pem -new -sha256 -out csr/client.csr
openssl ca -config ./openssl.cnf -create_serial -extensions etcd_client -days $CERT_DAYS -notext -md sha256 -in csr/client.csr -out certs/client.pem
```

* private/client_key.pem
* private/client_key_insecure.pem
* certs/client.pem

## Appendix

openssl.conf

```
#
# OpenSSL example configuration file.
# This is mostly being used for generation of certificate requests.
#

# This definition stops the following lines choking if HOME isn't
# defined.
HOME                   = .
RANDFILE               = $ENV::HOME/.rnd

# Change those for you own needs.
KEY_SIZE               = 4096
KEY_COUNTRY            = DE
KEY_PROVINCE           = BAVARIA
KEY_CITY               = MUNICH
KEY_ORG                = etcd-ca
KEY_ORGUNIT            = NTT DATA Certificate Authority
KEY_COMMON_NAME        = NTT DATA Root CA
KEY_EMAIL              = admin@nttdata.com
ETCD_SAN               = "IP:127.0.0.1"

# Extra OBJECT IDENTIFIER info:
#oid_file               = $ENV::HOME/.oid
oid_section             = new_oids

# To use this configuration file with the "-extfile" option of the
# "openssl x509" utility, name here the section containing the
# X.509v3 extensions to use:
# extensions            =
# (Alternatively, use a configuration file that has only
# X.509v3 extensions in its main [= default] section.)

[ new_oids ]

# We can add new OIDs in here for use by 'ca', 'req' and 'ts'.
# Add a simple OID like this:
# testoid1=1.2.3.4
# Or use config file substitution like this:
# testoid2=${testoid1}.5.6

# Policies used by the TSA examples.
tsa_policy1 = 1.2.3.4.1
tsa_policy2 = 1.2.3.4.5.6
tsa_policy3 = 1.2.3.4.5.7

# OpenSSL root CA configuration file.
# Copy to `/root/ca/openssl.cnf`.

[ ca ]
# `man ca`
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
dir               = .
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
RANDFILE          = $dir/private/.rand

# The root key and root certificate.
private_key       = $dir/private/ca_key.pem
certificate       = $dir/certs/ca_cert.pem

# For certificate revocation lists.
crlnumber         = $dir/crlnumber
crl               = $dir/crl/ca_crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_etcd

[ policy_strict ]
# The root CA should only sign intermediate certificates that match.
# See the POLICY FORMAT section of `man ca`.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ policy_loose ]
# Allow the intermediate CA to sign a more diverse range of certificates.
# See the POLICY FORMAT section of the `ca` man page.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ policy_etcd ]
organizationName = optional
commonName = supplied

[ req ]
# Options for the `req` tool (`man req`).
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only
attributes          = req_attributes
req_extensions      = etcd_client

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_ca

[ req_attributes ]

[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName                     = Country Name (2 letter code)
countryName_default             = $ENV::KEY_COUNTRY
countryName_min                 = 2
countryName_max                 = 2
stateOrProvinceName             = State or Province Name (full name)
stateOrProvinceName_default     = $ENV::KEY_PROVINCE
localityName                    = Locality Name (eg, city)
localityName_default            = $ENV::KEY_CITY
0.organizationName              = Organization Name (eg, company)
0.organizationName_default      = $ENV::KEY_ORG
# we can do this but it is not needed normally :-)
#1.organizationName             = Second Organization Name (eg, company)
#1.organizationName_default     = World Wide Web Pty Ltd
organizationalUnitName          = Organizational Unit Name (eg, section)
organizationalUnitName_default  = $ENV::KEY_ORGUNIT
commonName                      = Common Name (e.g. server FQDN or YOUR name)
commonName_default              = $ENV::KEY_COMMON_NAME
commonName_max                  = 64
emailAddress                    = Email Address
emailAddress_default            = $ENV::KEY_EMAIL
emailAddress_max                = 64

[ v3_ca ]
basicConstraints       = CA:TRUE
keyUsage               = keyCertSign,cRLSign
subjectKeyIdentifier   = hash

[ etcd_client ]
basicConstraints       = CA:FALSE
extendedKeyUsage       = clientAuth
keyUsage               = digitalSignature, keyEncipherment

[ etcd_peer ]
basicConstraints       = CA:FALSE
extendedKeyUsage       = clientAuth, serverAuth
keyUsage               = digitalSignature, keyEncipherment
subjectAltName         = ${ENV::ETCD_SAN}

[ etcd_server ]
basicConstraints       = CA:FALSE
extendedKeyUsage       = clientAuth, serverAuth
keyUsage               = digitalSignature, keyEncipherment
subjectAltName         = ${ENV::ETCD_SAN}
```

