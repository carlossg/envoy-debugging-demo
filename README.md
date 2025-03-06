# envoy-debugging-demo

## Setup
1. Generate certificates from common: `./generate-scenario-certs.sh [scenario] [problem|correct]`
2. Start services: `cd envoy-tests/scenarios/[scenario]; docker-compose up -d`

## Test Steps
Make initial request:
   ```bash
   docker compose exec curl curl http://envoy_sidecar:3128/
   ```
## Look for logs
   ```bash
   docker compose logs envoy_sidecar | grep '\[debug\]'
   ```

## Stop before going to next scenario
   ```bash
   docker compose down
   ```

