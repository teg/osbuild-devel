#!/bin/bash
set -euxo pipefail

# Generate all X.509 certificates for the tests
# The whole generation is done in a $CADIR to better represent how osbuild-ca
# it.
scriptloc=$(cd $(dirname $0) && pwd)
CERTDIR=$(cd "$1" && pwd)
OPENSSL_CONFIG="${scriptloc}/openssl.cnf"
CADIR=$(mktemp -d)

pushd $CADIR
    mkdir certs private
    touch index.txt

    # Generate a CA.
    openssl req -config $OPENSSL_CONFIG \
        -keyout private/ca.key.pem \
        -new -nodes -x509 -extensions osbuild_ca_ext \
        -out ca.cert.pem -subj "/CN=osbuild.org"

    # Copy the private key to the location expected by the tests
    cp ca.cert.pem "$CERTDIR"/ca-crt.pem

    # Generate a composer certificate.
    openssl req -config $OPENSSL_CONFIG \
        -keyout "$CERTDIR"/composer-key.pem \
        -new -nodes \
        -out /tmp/composer-csr.pem \
        -subj "/CN=localhost/emailAddress=osbuild@example.com" \
        -addext "subjectAltName=DNS:composer"

    openssl ca -batch -config $OPENSSL_CONFIG \
        -extensions osbuild_server_ext \
        -in /tmp/composer-csr.pem \
        -out "$CERTDIR"/composer-crt.pem

    # chown _osbuild-composer "$CERTDIR"/composer-*.pem

    # Generate a worker certificate.
    openssl req -config $OPENSSL_CONFIG \
        -keyout "$CERTDIR"/worker-key.pem \
        -new -nodes \
        -out /tmp/worker-csr.pem \
        -subj "/CN=localhost/emailAddress=osbuild@example.com" \
        -addext "subjectAltName=DNS:localhost"

    openssl ca -batch -config $OPENSSL_CONFIG \
        -extensions osbuild_client_ext \
        -in /tmp/worker-csr.pem \
        -out "$CERTDIR"/worker-crt.pem

    # Generate a client certificate.
    openssl req -config $OPENSSL_CONFIG \
        -keyout "$CERTDIR"/client-key.pem \
        -new -nodes \
        -out /tmp/client-csr.pem \
        -subj "/CN=client.osbuild.org/emailAddress=osbuild@example.com" \
        -addext "subjectAltName=DNS:client.osbuild.org"

    openssl ca -batch -config $OPENSSL_CONFIG \
        -extensions osbuild_client_ext \
        -in /tmp/client-csr.pem \
        -out "$CERTDIR"/client-crt.pem

    # Client keys are used by tests to access the composer APIs. Allow all users access.
    chmod 644 "$CERTDIR"/client-key.pem

    # Generate a kojihub certificate.
    openssl req -config $OPENSSL_CONFIG \
        -keyout "$CERTDIR"/kojihub-key.pem \
        -new -nodes \
        -out /tmp/kojihub-csr.pem \
        -subj "/CN=localhost/emailAddress=osbuild@example.com" \
        -addext "subjectAltName=DNS:localhost"

    openssl ca -batch -config $OPENSSL_CONFIG \
        -extensions osbuild_server_ext \
        -in /tmp/kojihub-csr.pem \
        -out "$CERTDIR"/kojihub-crt.pem

popd
