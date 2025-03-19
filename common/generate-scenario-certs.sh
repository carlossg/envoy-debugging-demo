#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 <scenario> <mode>"
    echo "Scenarios: 1, 2, 3, 4, 5"
    echo "Modes: problem, correct"
    echo "1 - cert-expiration"
    echo "2 - invalid-signature"
    echo "3 - key-mismatch"
    echo "4 - san-mismatch"
    echo "5 - concurrent-requests"
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
    1|2|3|4|5)
        ;;
    *)
        echo "Invalid scenario. Must be one of: 1, 2, 3, 4, 5"
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
mkdir -p "../envoy-tests/scenarios/$SCENARIO/certs/envoy_downstream"
mkdir -p "../envoy-tests/scenarios/$SCENARIO/certs/envoy_upstream"

# Function to generate standard certificates (correct mode)
generate_correct_certs() {
    local dir=$1
    
    # Generate CA
    openssl genpkey -algorithm RSA -out "$dir/ca.key"
    openssl req -x509 -new -nodes -key "$dir/ca.key" -sha256 -days 365 \
        -out "$dir/ca.pem" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=Test CA"

    # Create OpenSSL config for downstream with SAN
    cat > "$dir/envoy_downstream/openssl.cnf" <<EOF
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
CN = envoy-debugging-demo

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = envoy-debugging-demo
EOF

    # Generate downstream certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_downstream/key.pem"
    openssl req -new -key "$dir/envoy_downstream/key.pem" \
        -config "$dir/envoy_downstream/openssl.cnf" \
        -out "$dir/envoy_downstream/cert.csr"
    openssl x509 -req -in "$dir/envoy_downstream/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -extfile "$dir/envoy_downstream/openssl.cnf" \
        -extensions req_ext \
        -out "$dir/envoy_downstream/cert.pem" -days 365

    # Create OpenSSL config for upstream with SAN
    cat > "$dir/envoy_upstream/openssl.cnf" <<EOF
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
CN = envoy-debugging-demo

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = envoy-debugging-demo
EOF

    # Generate upstream certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_upstream/key.pem"
    openssl req -new -key "$dir/envoy_upstream/key.pem" \
        -config "$dir/envoy_upstream/openssl.cnf" \
        -out "$dir/envoy_upstream/cert.csr"
    openssl x509 -req -in "$dir/envoy_upstream/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -extfile "$dir/envoy_upstream/openssl.cnf" \
        -extensions req_ext \
        -out "$dir/envoy_upstream/cert.pem" -days 365

    # Copy the trusted CA cert to both directories
    cp "$dir/ca.pem" "$dir/envoy_downstream/"
    cp "$dir/ca.pem" "$dir/envoy_upstream/"
}

# Function to generate certificates for 1 scenario
generate_expired_certs() {
    local dir=$1
    
    # Generate CA
    openssl genpkey -algorithm RSA -out "$dir/ca.key"
    openssl req -x509 -new -nodes -key "$dir/ca.key" -sha256 -days 365 \
        -out "$dir/ca.pem" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=Test CA"

    # Generate valid downstream certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_downstream/key.pem"
    openssl req -new -key "$dir/envoy_downstream/key.pem" \
        -out "$dir/envoy_downstream/cert.csr" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=envoy_downstream" \
        -config "../../../common/openssl.cnf"
    openssl x509 -req -in "$dir/envoy_downstream/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -out "$dir/envoy_downstream/cert.pem" -days 365 \
        -extfile <(echo "subjectAltName=DNS:envoy_downstream")

    # Generate expired upstream certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_upstream/key.pem"
    openssl req -new -key "$dir/envoy_upstream/key.pem" \
        -out "$dir/envoy_upstream/cert.csr" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=envoy_upstream" \
        -config "../../../common/openssl.cnf"
    openssl x509 -req -in "$dir/envoy_upstream/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -out "$dir/envoy_upstream/cert.pem" -days 0 \
        -extfile <(echo "subjectAltName=DNS:envoy_upstream")

    cp "$dir/ca.pem" "$dir/envoy_downstream/"
    cp "$dir/ca.pem" "$dir/envoy_upstream/"
}

# Function to generate certificates for 2 scenario
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

    # Create OpenSSL config for downstream with SAN
    cat > "$dir/envoy_downstream/openssl.cnf" <<EOF
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
CN = envoy-debugging-demo

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = envoy-debugging-demo
EOF

    # Generate downstream certificate signed by different CA
    openssl genpkey -algorithm RSA -out "$dir/envoy_downstream/key.pem"
    openssl req -new -key "$dir/envoy_downstream/key.pem" \
        -config "$dir/envoy_downstream/openssl.cnf" \
        -out "$dir/envoy_downstream/cert.csr"
    openssl x509 -req -in "$dir/envoy_downstream/cert.csr" \
        -CA "$dir/different_ca.pem" -CAkey "$dir/different_ca.key" -CAcreateserial \
        -extfile "$dir/envoy_downstream/openssl.cnf" \
        -extensions req_ext \
        -out "$dir/envoy_downstream/cert.pem" -days 365

    # Create OpenSSL config for upstream with SAN
    cat > "$dir/envoy_upstream/openssl.cnf" <<EOF
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
CN = envoy-debugging-demo

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = envoy-debugging-demo
EOF

    # Generate valid upstream certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_upstream/key.pem"
    openssl req -new -key "$dir/envoy_upstream/key.pem" \
        -config "$dir/envoy_upstream/openssl.cnf" \
        -out "$dir/envoy_upstream/cert.csr"
    openssl x509 -req -in "$dir/envoy_upstream/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -extfile "$dir/envoy_upstream/openssl.cnf" \
        -extensions req_ext \
        -out "$dir/envoy_upstream/cert.pem" -days 365

    # Copy the trusted CA cert to both directories
    cp "$dir/ca.pem" "$dir/envoy_downstream/"
    cp "$dir/ca.pem" "$dir/envoy_upstream/"
}

# Function to generate certificates for 3 scenario
generate_key_mismatch_certs() {
    local dir=$1
    
    # Generate CA
    openssl genpkey -algorithm RSA -out "$dir/ca.key"
    openssl req -x509 -new -nodes -key "$dir/ca.key" -sha256 -days 365 \
        -out "$dir/ca.pem" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=Test CA"

    # Generate downstream certificate with mismatched key
    openssl genpkey -algorithm RSA -out "$dir/envoy_downstream/correct.key"
    openssl req -new -key "$dir/envoy_downstream/correct.key" \
        -out "$dir/envoy_downstream/cert.csr" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=envoy_downstream"
    openssl x509 -req -in "$dir/envoy_downstream/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -out "$dir/envoy_downstream/cert.pem" -days 365
    
    # Generate different key (this causes the mismatch)
    openssl genpkey -algorithm RSA -out "$dir/envoy_downstream/key.pem"

    # Generate valid upstream certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_upstream/key.pem"
    openssl req -new -key "$dir/envoy_upstream/key.pem" \
        -out "$dir/envoy_upstream/cert.csr" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=envoy_upstream"
    openssl x509 -req -in "$dir/envoy_upstream/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -out "$dir/envoy_upstream/cert.pem" -days 365

    cp "$dir/ca.pem" "$dir/envoy_downstream/"
    cp "$dir/ca.pem" "$dir/envoy_upstream/"
}

# Function to generate certificates for 4 scenario
generate_san_mismatch_certs() {
    local dir=$1
    
    # Generate CA
    openssl genpkey -algorithm RSA -out "$dir/ca.key"
    openssl req -x509 -new -nodes -key "$dir/ca.key" -sha256 -days 365 \
        -out "$dir/ca.pem" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=Test CA"

    # Create OpenSSL config for downstream with specific SAN
    cat > "$dir/envoy_downstream/openssl.cnf" <<EOF
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

    # Generate downstream certificate with specific SAN
    openssl genpkey -algorithm RSA -out "$dir/envoy_downstream/key.pem"
    openssl req -new -key "$dir/envoy_downstream/key.pem" \
        -config "$dir/envoy_downstream/openssl.cnf" \
        -out "$dir/envoy_downstream/cert.csr"
    openssl x509 -req -in "$dir/envoy_downstream/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -extfile "$dir/envoy_downstream/openssl.cnf" \
        -extensions req_ext \
        -out "$dir/envoy_downstream/cert.pem" -days 365

    # Generate upstream certificate
    openssl genpkey -algorithm RSA -out "$dir/envoy_upstream/key.pem"
    openssl req -new -key "$dir/envoy_upstream/key.pem" \
        -out "$dir/envoy_upstream/cert.csr" \
        -subj "/C=US/ST=California/L=San Francisco/O=Test/CN=envoy_upstream"
    openssl x509 -req -in "$dir/envoy_upstream/cert.csr" \
        -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial \
        -out "$dir/envoy_upstream/cert.pem" -days 365

    cp "$dir/ca.pem" "$dir/envoy_downstream/"
    cp "$dir/ca.pem" "$dir/envoy_upstream/"
}

# Main execution
cd "../envoy-tests/scenarios/$SCENARIO" || exit 1

case $MODE in
    correct)
        generate_correct_certs "certs"
        ;;
    problem)
        case $SCENARIO in
            1)
                generate_expired_certs "certs"
                ;;
            2)
                generate_invalid_signature_certs "certs"
                ;;
            3)
                generate_key_mismatch_certs "certs"
                ;;
            4)
                generate_san_mismatch_certs "certs"
                ;;
            5)
                generate_correct_certs "certs"
                ;;
        esac
        ;;
esac

# Cleanup
rm -f certs/*.srl certs/*.csr
rm -f certs/envoy_downstream/*.csr certs/envoy_downstream/openssl.cnf
rm -f certs/envoy_upstream/*.csr

echo "Certificate generation complete for $SCENARIO in $MODE mode"
echo
echo "Certificates expiration dates:"
echo -n "Downstream: "
openssl x509 -in certs/envoy_downstream/cert.pem -noout -enddate
echo -n "Upstream: "
openssl x509 -in certs/envoy_upstream/cert.pem -noout -enddate
