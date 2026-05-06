#!/usr/bin/env bash
set -euo pipefail

rm -rf /tmp/test-cleanup-$$ || true
kubectl delete ns non-existent || true
kubectl apply -f /tmp/broken.yaml || true
grep "pattern" /tmp/nonexistent.log || true