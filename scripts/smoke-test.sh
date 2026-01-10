cd ~/ea-arch-module

echo "== Cluster =="
kubectl get nodes || exit 1
kubectl get pods -A | head -50

echo "== Observability =="
kubectl -n observability get pods
kubectl -n observability logs deploy/otel-collector --tail=5 || true

echo "== OpenChat base pods =="
kubectl -n openchat-dev get pods
kubectl -n openchat-dev get svc

echo "== RabbitMQ =="
kubectl -n messaging get pods
kubectl -n messaging get svc rabbitmq

echo "== Create thread/post and verify moderation =="
kubectl -n openchat-dev port-forward svc/thread-svc 8080:80 >/tmp/pf-thread.log 2>&1 &
PF1=$!
kubectl -n openchat-dev port-forward svc/post-svc 8081:80 >/tmp/pf-post.log 2>&1 &
PF2=$!
sleep 2

curl -sf http://localhost:8080/health >/dev/null
curl -sf http://localhost:8081/health >/dev/null

curl -sf -X POST http://localhost:8080/threads \
  -H "content-type: application/json" \
  -d '{"topic":"Smoke Test","country_code":"IE"}' >/dev/null

curl -sf -X POST http://localhost:8081/posts \
  -H "content-type: application/json" \
  -d '{"thread_id":1,"text":"this is spam","country_code":"IE"}' >/dev/null

kill $PF1 $PF2 || true
sleep 1

kubectl -n openchat-dev exec -it sts/postgres -- \
  psql -U openchat -d openchat -c "select * from moderation order by moderated_at desc limit 5;" || exit 1

echo "== KEDA scaledobject =="
kubectl -n openchat-dev get scaledobject || true

echo "== Kyverno (if installed) =="
kubectl get pods -n kyverno >/dev/null 2>&1 && kubectl get clusterpolicy || echo "Kyverno not installed"

echo "== Keycloak (if installed) =="
kubectl get pods -n identity >/dev/null 2>&1 && kubectl -n identity get pods || echo "Keycloak not installed"

echo "== Velero (if installed) =="
kubectl get pods -n velero >/dev/null 2>&1 && velero backup-location get || echo "Velero not installed or velero CLI missing"

echo "Smoke test complete."