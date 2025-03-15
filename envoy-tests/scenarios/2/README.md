docker compose up -d
./generate-scenario-certs.sh 2 problem
docker-compose exec curl curl -v http://envoy_downstream:3128
docker compose logs envoy_downstream |grep 'debug'

envoy_downstream-1  | [2025-03-05 07:22:38.631][15][debug][connection] [source/common/tls/ssl_socket.cc:251] [Tags: "ConnectionId":"1"] remote address:172.20.0.4:443,TLS_error:|268436504:SSL routines:OPENSSL_internal:TLSV1_ALERT_UNKNOWN_CA:TLS_error_end


docker compose logs envoy_upstream |grep 'debug'

envoy_upstream-1  | [2025-03-05 07:22:38.631][15][debug][connection] [source/common/tls/cert_validator/default_validator.cc:321] verify cert failed: X509_verify_cert: certificate verification error at depth 0: unable to get local issuer certificate
envoy_upstream-1  | [2025-03-05 07:22:38.631][15][debug][connection] [source/common/tls/ssl_socket.cc:251] [Tags: "ConnectionId":"0"] remote address:172.20.0.5:50218,TLS_error:|268435581:SSL routines:OPENSSL_internal:CERTIFICATE_VERIFY_FAILED:TLS_error_end
