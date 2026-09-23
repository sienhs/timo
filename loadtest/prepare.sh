#!/bin/bash
set -euo pipefail
cd /opt/loadtest
cloud-init status --wait
export MYSQL_PWD="$TEST_DB_PASSWORD"
db=(mysql --host="$DB_HOST" --user=loadtest --database=timo_loadtest)
max_connections=$("${db[@]}" -Nse 'SELECT @@max_connections')
required_connections=$((APP_INSTANCE_COUNT * DB_POOL_SIZE + 20))
test "$max_connections" -ge "$required_connections" || { echo "Need at least $required_connections DB connections ($((APP_INSTANCE_COUNT * DB_POOL_SIZE)) app + 20 reserve)" >&2; exit 1; }
# Never drop a database; a repeat prepare fails before touching existing data.
if [ "${INITIALIZE_DB:-false}" = true ]; then
  count=$("${db[@]}" -Nse "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='timo_loadtest'")
  test "$count" = 0 || { echo 'Database is not empty; destroy/recreate for a clean run.' >&2; exit 1; }
  "${db[@]}" < schema.sql
  export PASSWORD_HASH=$(docker run --rm httpd:2.4-alpine htpasswd -bnBC 10 '' password | tr -d ':\r\n')
  python3 seed.py | "${db[@]}"
fi
python3 - <<'PY'
import os
# Run the production code path against disposable data, while explicitly
# disabling every background or external side effect for this measurement.
env = dict(SPRING_PROFILES_ACTIVE='prod', DB_URL=f"jdbc:mysql://{os.environ['DB_HOST']}:3306/timo_loadtest?connectionTimeZone=Asia/Seoul&characterEncoding=UTF-8", DB_USERNAME='loadtest', DB_PASSWORD=os.environ['TEST_DB_PASSWORD'], REDIS_HOST=os.environ['REDIS_HOST'], REDIS_PORT=os.environ['REDIS_PORT'], REDIS_PASSWORD=os.environ['REDIS_PASSWORD'], WAITING_QUEUE_ACTIVE_LIMIT=os.environ['WAITING_QUEUE_ACTIVE_LIMIT'], JWT_SECRET=os.environ['JWT_SECRET'], ENTRY_PASS_SECRET=os.environ['ENTRY_PASS_SECRET'], WALLET_MASTER_KEY=os.environ['WALLET_MASTER_KEY'], ADMIN_PRIVATE_KEY='', SOLAPI_API_KEY='loadtest', SOLAPI_API_SECRET='loadtest', SOLAPI_SENDER_PHONE='01000000000', S3_PUBLIC_BUCKET_NAME='loadtest-unused', IMAGE_BASE_URL='http://localhost/unused', AWS_REGION=os.environ['AWS_REGION'], FIREBASE_MESSAGING_ENABLED='false', SCHEDULING_ENABLED='false', BLOCKCHAIN_RPC_URL='http://127.0.0.1:8545', OTEL_SDK_DISABLED='true', MANAGEMENT_TRACING_ENABLED='false', MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENABLED='false', TRACING_OTLP_ENDPOINT='http://127.0.0.1:4318', JWT_ACCESS_TOKEN_TTL='2h')
with open('backend.env','w') as f:
    f.write(f"SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE={os.environ['DB_POOL_SIZE']}\nSPRING_DATASOURCE_HIKARI_MINIMUM_IDLE=1\n")
    for k,v in env.items():
        assert '\n' not in v and '\r' not in v
        f.write(f'{k}={v}\n')
os.chmod('backend.env',0o600)
PY
registry="${IMAGE%%/*}"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$registry"
docker pull "$IMAGE"
docker run -d --name timo-loadtest --restart unless-stopped --env-file backend.env -p 8080:8080 --log-opt max-size=10m --log-opt max-file=3 "$IMAGE"
for i in {1..90}; do
  if curl -fsS http://localhost:8080/actuator/health >/dev/null; then exit 0; fi
  sleep 2
done
docker logs --tail 100 timo-loadtest
exit 1
