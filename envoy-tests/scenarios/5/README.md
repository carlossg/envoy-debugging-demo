# Concurrent Requests Test Scenario

This scenario tests Envoy's behavior under high concurrent load with rate limiting and circuit breaking enabled.

## Configuration Details

- Rate limiting: 1000 requests/second max
- Circuit breaker: 1000 concurrent connections
- Load test: 1000 concurrent users ramping up over 30 seconds

## Test Steps

1. Start the environment:
```bash
docker-compose up -d
```

2. Wait for services to initialize (about 30 seconds)

3. Start the load test:
```bash
docker-compose exec jmeter jmeter -n -t /test/test-plan.jmx -l /test/results/test.jtl
```

4. Monitor results:
- Grafana dashboard: http://localhost:3000
- Prometheus metrics: http://localhost:9090
- JMeter results: ./jmeter/results/dashboard/

## Expected Behavior

1. Initial requests succeed
2. Rate limiting kicks in at 1000 req/sec
3. Some requests receive 429 (Too Many Requests)
4. Circuit breaker may trip if connections exceed 1000

## Key Metrics to Watch

- Rate limiting metrics: `envoy_http_local_rate_limit`
- Circuit breaker metrics: `envoy_cluster_circuit_breakers_default_cx_open`
- Request status codes: `envoy_http_downstream_rq_xx`

####
Key differences from the downstream configuration:
Higher rate limits (2000 vs 1000) to ensure the bottleneck is at the downstream
Added retry policy for upstream requests
Added health checks for the backend service
Added outlier detection for circuit breaking
Higher circuit breaker thresholds
Added timeout configuration for routes
Points to service-http instead of another Envoy proxy
The configuration includes:
1. Rate limiting:
2000 requests/second max
200 tokens added per second
Token bucket for smooth rate limiting
2. Circuit Breaking:
Max 2000 concurrent connections
Max 2000 pending requests
Max 2000 concurrent requests
Max 3 retries
3. Retry Policy:
Retries on various failure conditions
Exponential backoff (0.1s to 1s)
Maximum 3 retries
4. Health Checking:
5-second interval
1-second timeout
Checks /health endpoint
5. Outlier Detection:
Ejects hosts after 5 consecutive 5xx errors
30-second base ejection time
Maximum 50% of hosts can be ejected
This configuration is designed to:
Handle higher load than the downstream
Provide better visibility into backend service health
Implement graceful degradation under load
Protect the backend service from overload
Provide detailed metrics for monitoring
