#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 <scenario> <mode>"
    echo "Scenarios: cert-expiration, invalid-signature, key-mismatch, san-mismatch"
    echo "Modes: problem, correct"
    exit 1
}

# Check if we have correct number of arguments
if [ "$#" -ne 2 ]; then
    usage
fi

SCENARIO=$1
MODE=$2

# Validate scenario argument
case $SCENARIO in
    cert-expiration|invalid-signature|key-mismatch|san-mismatch|concurrent-requests)
        ;;
    *)
        echo "Invalid scenario. Must be one of: cert-expiration, invalid-signature, key-mismatch, san-mismatch, concurrent-requests"
        exit 1
        ;;
esac

# Validate mode argument
case $MODE in
    problem|correct)
        ;;
    *)
        echo "Invalid mode. Must be either 'problem' or 'correct'"
        exit 1
        ;;
esac

# Create directories if they don't exist
mkdir -p "../envoy-tests/scenarios/$SCENARIO/certs/envoy_sidecar"
mkdir -p "../envoy-tests/scenarios/$SCENARIO/certs/envoy_peer"

# Function to generate standard certificates (correct mode)
generate_correct_certs() {
    local dir=$1
    
    # Generate CA
    openssl genpkey -algorithm RSA -out "$dir/ca.key"
    openssl req -x509 -new -nodes -key "$dir/ca.key" -sha256 -days 365 \
        -out "$dir/ca.pem" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=Test CA"

    # Create OpenSSL config for sidecar with SAN
    cat > "$dir/envoy_sidecar/openssl.cnf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = US
ST = California
L = San Francisco
O = Test
CN = envoy_peer

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = envoy_peer
EOF

    # Generate sidecar certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_sidecar/key.pem"
    openssl req -new -key "$dir/envoy_sidecar/key.pem" \
        -config "$dir/envoy_sidecar/openssl.cnf" \
        -out "$dir/envoy_sidecar/cert.csr"
    openssl x509 -req -in "$dir/envoy_sidecar/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -extfile "$dir/envoy_sidecar/openssl.cnf" \
        -extensions req_ext \
        -out "$dir/envoy_sidecar/cert.pem" -days 365

    # Create OpenSSL config for peer with SAN
    cat > "$dir/envoy_peer/openssl.cnf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = US
ST = California
L = San Francisco
O = Test
CN = envoy_peer

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = envoy_peer
EOF

    # Generate peer certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_peer/key.pem"
    openssl req -new -key "$dir/envoy_peer/key.pem" \
        -config "$dir/envoy_peer/openssl.cnf" \
        -out "$dir/envoy_peer/cert.csr"
    openssl x509 -req -in "$dir/envoy_peer/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -extfile "$dir/envoy_peer/openssl.cnf" \
        -extensions req_ext \
        -out "$dir/envoy_peer/cert.pem" -days 365

    # Copy the trusted CA cert to both directories
    cp "$dir/ca.pem" "$dir/envoy_sidecar/"
    cp "$dir/ca.pem" "$dir/envoy_peer/"
}

# Function to generate certificates for cert-expiration scenario
generate_expired_certs() {
    local dir=$1
    
    # Generate CA
    openssl genpkey -algorithm RSA -out "$dir/ca.key"
    openssl req -x509 -new -nodes -key "$dir/ca.key" -sha256 -days 365 \
        -out "$dir/ca.pem" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=Test CA"

    # Generate expired sidecar certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_sidecar/key.pem"
    openssl req -new -key "$dir/envoy_sidecar/key.pem" \
        -out "$dir/envoy_sidecar/cert.csr" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=envoy_sidecar" \
        -config "../../../common/openssl.cnf"
    openssl x509 -req -in "$dir/envoy_sidecar/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -out "$dir/envoy_sidecar/cert.pem" -days 0 \
        -extfile <(echo "subjectAltName=DNS:envoy_sidecar")

    # Generate valid peer certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_peer/key.pem"
    openssl req -new -key "$dir/envoy_peer/key.pem" \
        -out "$dir/envoy_peer/cert.csr" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=envoy_peer" \
        -config "../../../common/openssl.cnf"
    openssl x509 -req -in "$dir/envoy_peer/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -out "$dir/envoy_peer/cert.pem" -days 365 \
        -extfile <(echo "subjectAltName=DNS:envoy_peer")

    cp "$dir/ca.pem" "$dir/envoy_sidecar/"
    cp "$dir/ca.pem" "$dir/envoy_peer/"
}

# Function to generate certificates for invalid-signature scenario
generate_invalid_signature_certs() {
    local dir=$1
    
    # Generate valid CA
    openssl genpkey -algorithm RSA -out "$dir/ca.key"
    openssl req -x509 -new -nodes -key "$dir/ca.key" -sha256 -days 365 \
        -out "$dir/ca.pem" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=Test CA"

    # Generate different CA for invalid signature
    openssl genpkey -algorithm RSA -out "$dir/different_ca.key"
    openssl req -x509 -new -nodes -key "$dir/different_ca.key" -sha256 -days 365 \
        -out "$dir/different_ca.pem" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=Different CA"

    # Create OpenSSL config for sidecar with SAN
    cat > "$dir/envoy_sidecar/openssl.cnf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = US
ST = California
L = San Francisco
O = Test
CN = envoy_peer

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = envoy_peer
EOF

    # Generate sidecar certificate signed by different CA
    openssl genpkey -algorithm RSA -out "$dir/envoy_sidecar/key.pem"
    openssl req -new -key "$dir/envoy_sidecar/key.pem" \
        -config "$dir/envoy_sidecar/openssl.cnf" \
        -out "$dir/envoy_sidecar/cert.csr"
    openssl x509 -req -in "$dir/envoy_sidecar/cert.csr" \
        -CA "$dir/different_ca.pem" -CAkey "$dir/different_ca.key" -CAcreateserial \
        -extfile "$dir/envoy_sidecar/openssl.cnf" \
        -extensions req_ext \
        -out "$dir/envoy_sidecar/cert.pem" -days 365

    # Create OpenSSL config for peer with SAN
    cat > "$dir/envoy_peer/openssl.cnf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = US
ST = California
L = San Francisco
O = Test
CN = envoy_peer

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = envoy_peer
EOF

    # Generate valid peer certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_peer/key.pem"
    openssl req -new -key "$dir/envoy_peer/key.pem" \
        -config "$dir/envoy_peer/openssl.cnf" \
        -out "$dir/envoy_peer/cert.csr"
    openssl x509 -req -in "$dir/envoy_peer/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -extfile "$dir/envoy_peer/openssl.cnf" \
        -extensions req_ext \
        -out "$dir/envoy_peer/cert.pem" -days 365

    # Copy the trusted CA cert to both directories
    cp "$dir/ca.pem" "$dir/envoy_sidecar/"
    cp "$dir/ca.pem" "$dir/envoy_peer/"
}

# Function to generate certificates for key-mismatch scenario
generate_key_mismatch_certs() {
    local dir=$1
    
    # Generate CA
    openssl genpkey -algorithm RSA -out "$dir/ca.key"
    openssl req -x509 -new -nodes -key "$dir/ca.key" -sha256 -days 365 \
        -out "$dir/ca.pem" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=Test CA"

    # Generate sidecar certificate with mismatched key
    openssl genpkey -algorithm RSA -out "$dir/envoy_sidecar/correct.key"
    openssl req -new -key "$dir/envoy_sidecar/correct.key" \
        -out "$dir/envoy_sidecar/cert.csr" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=envoy_sidecar"
    openssl x509 -req -in "$dir/envoy_sidecar/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -out "$dir/envoy_sidecar/cert.pem" -days 365
    
    # Generate different key (this causes the mismatch)
    openssl genpkey -algorithm RSA -out "$dir/envoy_sidecar/key.pem"

    # Generate valid peer certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_peer/key.pem"
    openssl req -new -key "$dir/envoy_peer/key.pem" \
        -out "$dir/envoy_peer/cert.csr" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=envoy_peer"
    openssl x509 -req -in "$dir/envoy_peer/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -out "$dir/envoy_peer/cert.pem" -days 365

    cp "$dir/ca.pem" "$dir/envoy_sidecar/"
    cp "$dir/ca.pem" "$dir/envoy_peer/"
}

# Function to generate certificates for san-mismatch scenario
generate_san_mismatch_certs() {
    local dir=$1
    
    # Generate CA
    openssl genpkey -algorithm RSA -out "$dir/ca.key"
    openssl req -x509 -new -nodes -key "$dir/ca.key" -sha256 -days 365 \
        -out "$dir/ca.pem" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=Test CA"

    # Create OpenSSL config for sidecar with specific SAN
    cat > "$dir/envoy_sidecar/openssl.cnf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = US
ST = California
L = San Francisco
O = Test
CN = test.example.com

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = test.example.com
EOF

    # Generate sidecar certificate with specific SAN
    openssl genpkey -algorithm RSA -out "$dir/envoy_sidecar/key.pem"
    openssl req -new -key "$dir/envoy_sidecar/key.pem" \
        -config "$dir/envoy_sidecar/openssl.cnf" \
        -out "$dir/envoy_sidecar/cert.csr"
    openssl x509 -req -in "$dir/envoy_sidecar/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -extfile "$dir/envoy_sidecar/openssl.cnf" \
        -extensions req_ext \
        -out "$dir/envoy_sidecar/cert.pem" -days 365

    # Generate peer certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_peer/key.pem"
    openssl req -new -key "$dir/envoy_peer/key.pem" \
        -out "$dir/envoy_peer/cert.csr" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=envoy_peer"
    openssl x509 -req -in "$dir/envoy_peer/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -out "$dir/envoy_peer/cert.pem" -days 365

    cp "$dir/ca.pem" "$dir/envoy_sidecar/"
    cp "$dir/ca.pem" "$dir/envoy_peer/"
}

# Main execution
cd "../envoy-tests/scenarios/$SCENARIO" || exit 1

case $MODE in
    correct)
        generate_correct_certs "certs"
        ;;
    problem)
        case $SCENARIO in
            cert-expiration)
                generate_expired_certs "certs"
                ;;
            invalid-signature)
                generate_invalid_signature_certs "certs"
                ;;
            key-mismatch)
                generate_key_mismatch_certs "certs"
                ;;
            san-mismatch)
                generate_san_mismatch_certs "certs"
                ;;
            concurrent-requests)
                generate_concurrent_requests_certs "certs"
                ;;
        esac
        ;;
esac

# Cleanup
rm -f certs/*.srl certs/*.csr
rm -f certs/envoy_sidecar/*.csr certs/envoy_sidecar/openssl.cnf
rm -f certs/envoy_peer/*.csr

echo "Certificate generation complete for $SCENARIO in $MODE mode"
