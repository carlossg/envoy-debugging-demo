# envoy-debugging-demo

The architecture is as follows:

`curl -> envoy downstream (:3128) -> mTLS tunnel -> envoy upstream (:9443) -> service`

Scenarios:

1. certificate expiration
2. invalid certificate signature
3. key mismatch
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

### Check downstream certificates

```shell
docker compose exec envoy_downstream sh -c 'cat /etc/envoy/certs/cert.pem | openssl x509 -noout -subject -ext subjectAltName -date -modulus'
docker compose exec envoy_downstream sh -c 'cat /etc/envoy/certs/key.pem | openssl rsa -noout -modulus'
```

### Check upstream certificates

```shell
docker compose exec envoy_upstream sh -c 'cat /etc/envoy/certs/cert.pem | openssl x509 -noout -subject -ext subjectAltName -dates -modulus'
docker compose exec envoy_upstream sh -c 'cat /etc/envoy/certs/key.pem | openssl rsa -noout  -modulus'
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
