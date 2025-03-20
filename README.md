# envoy-debugging-demo

The architecture is as follows:

`curl -> envoy downstream (:3128) -> mTLS tunnel -> envoy upstream (:9443) -> service`

Scenarios:

1. certificate expiration
2. invalid certificate signature, certificates signed by different CA
3. key does not match certificate, modulus mismatch
4. san mismatch
5. too many concurrent requests

## Starting the scenarios

```shell
cd envoy-tests/scenarios/[scenario]; docker-compose up
```

to stop do `Ctrl-C` or

```shell
docker compose down
```

## Debugging

### Increase logging on downstream envoy

```shell
docker compose exec curl curl -s -X POST http://envoy_downstream:9901/logging?level=debug
```

or for specific component

```shell
docker compose exec curl curl -s -X POST http://envoy_downstream:9901/logging?connection=debug
```

### Increase logging on upstream envoy

```shell
docker compose exec curl curl -s -X POST http://envoy_upstream:9901/logging?level=debug
```

or for specific component

```shell
docker compose exec curl curl -s -X POST http://envoy_upstream:9901/logging?connection=debug
```

### Check downstream certificates and keys

```shell
docker compose exec envoy_downstream sh -c 'cat /etc/envoy/certs/cert.pem | openssl x509 -noout -text'
```

or

```shell
docker compose exec envoy_downstream sh -c 'cat /etc/envoy/certs/cert.pem | openssl x509 -noout -subject -ext subjectAltName -dates -modulus -issuer -ext authorityKeyIdentifier'
docker compose exec envoy_downstream sh -c 'cat /etc/envoy/certs/key.pem | openssl rsa -noout -modulus'
```

if container is not running, you can check the files in the `certs` directory

```shell
cat certs/envoy_downstream/cert.pem | openssl x509 -noout -subject -ext subjectAltName -dates -modulus -issuer -ext authorityKeyIdentifier
cat certs/envoy_downstream/key.pem | openssl rsa -noout -modulus
```

### Check upstream certificates and keys

```shell
docker compose exec envoy_upstream sh -c 'cat /etc/envoy/certs/cert.pem | openssl x509 -noout -text'
```

or

```shell
docker compose exec envoy_upstream sh -c 'cat /etc/envoy/certs/cert.pem | openssl x509 -noout -subject -ext subjectAltName -dates -modulus -issuer -ext authorityKeyIdentifier'
docker compose exec envoy_upstream sh -c 'cat /etc/envoy/certs/key.pem | openssl rsa -noout  -modulus'
```

if container is not running, you can check the files in the `certs` directory

```shell
cat certs/envoy_upstream/cert.pem | openssl x509 -noout -subject -ext subjectAltName -dates -modulus -issuer -ext authorityKeyIdentifier
cat certs/envoy_upstream/key.pem | openssl rsa -noout -modulus
```

### Check metrics

Go to

* [grafana](http://localhost:3000/)
* [prometheus](http://localhost:9090/)


## Setup

Generate certificates from common (already committed):

```shell
./generate-scenario-certs.sh [scenario] [problem|correct]`
```
