# envoy-debugging-demo

## Setup
1. Generate certificates from common: `./generate-scenario-certs.sh [scenario] [problem|correct]`
2. Start services: `cd envoy-tests/scenarios/[scenario]; docker-compose up -d`

## Test Steps
Make initial request:
   ```bash
   docker compose exec curl curl http://envoy_downstream:3128/
   ```
## Look for logs
   ```bash
   docker compose logs envoy_downstream | grep '\[debug\]'
   ```

## Stop before going to next scenario
   ```bash
   docker compose down
   ```


    echo "1 - cert-expiration"
    echo "2 - invalid-signature"
    echo "3 - key-mismatch"
    echo "4 - san-mismatch"
    echo "5 - concurrent-requests"