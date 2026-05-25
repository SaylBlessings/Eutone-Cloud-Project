#!/usr/bin/env bash
# ================================================================
# install.sh — Deploy ecommerce stack + monitoring on Minikube
# Usage: bash k8s/install.sh
# ================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================================"
echo " Ecommerce + Monitoring Stack — Minikube Installer"
echo "======================================================"

# ---- 0. Pre-flight checks ----
for cmd in minikube kubectl helm; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "[ERROR] '$cmd' is not installed. Please install it and retry."
    exit 1
  fi
done

echo "[INFO] Minikube status..."
minikube status || (echo "[ERROR] Minikube is not running. Start it with: minikube start" && exit 1)

# ---- 1. Enable required Minikube addons ----
echo ""
echo "[STEP 1] Enabling Minikube addons..."
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner
echo "[OK] Addons enabled."

# ---- 2. Create namespaces ----
echo ""
echo "[STEP 2] Creating namespaces..."
kubectl apply -f "${SCRIPT_DIR}/namespaces/namespaces.yaml"
echo "[OK] Namespaces ready."

# ---- 3. Add Helm repositories ----
echo ""
echo "[STEP 3] Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
echo "[OK] Helm repos updated."

# ---- 4. Install Prometheus (kube-prometheus-stack) ----
echo ""
echo "[STEP 4] Installing Prometheus (kube-prometheus-stack)..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values "${SCRIPT_DIR}/monitoring/prometheus-values.yaml" \
  --wait \
  --timeout 5m
echo "[OK] Prometheus installed."

# ---- 5. Install Grafana ----
echo ""
echo "[STEP 5] Installing Grafana..."
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --values "${SCRIPT_DIR}/monitoring/grafana-values.yaml" \
  --wait \
  --timeout 3m
echo "[OK] Grafana installed."

# ---- 6. Apply monitoring CRDs (ServiceMonitor, PrometheusRule) ----
echo ""
echo "[STEP 6] Applying monitoring manifests..."
kubectl apply -f "${SCRIPT_DIR}/monitoring/servicemonitor-ecommerce.yaml"
kubectl apply -f "${SCRIPT_DIR}/monitoring/alerting-rules.yaml"
echo "[OK] Monitoring manifests applied."

# ---- 7. Deploy ecommerce application ----
echo ""
echo "[STEP 7] Deploying ecommerce application..."
kubectl apply -f "${SCRIPT_DIR}/ecommerce/configmap.yaml"
kubectl apply -f "${SCRIPT_DIR}/ecommerce/secret.yaml"
kubectl apply -f "${SCRIPT_DIR}/ecommerce/deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/ecommerce/service.yaml"
kubectl apply -f "${SCRIPT_DIR}/ecommerce/hpa.yaml"
kubectl apply -f "${SCRIPT_DIR}/ecommerce/pdb.yaml"
kubectl apply -f "${SCRIPT_DIR}/ecommerce/networkpolicy.yaml"
kubectl apply -f "${SCRIPT_DIR}/ecommerce/ingress.yaml"
echo "[OK] Ecommerce manifests applied."

# ---- 8. Wait for ecommerce rollout ----
echo ""
echo "[STEP 8] Waiting for ecommerce rollout..."
kubectl rollout status deployment/ecommerce-app -n ecommerce --timeout=120s

# ---- 9. Print access info ----
MINIKUBE_IP=$(minikube ip)
echo ""
echo "======================================================"
echo " DEPLOYMENT COMPLETE"
echo "======================================================"
echo ""
echo " Add to /etc/hosts:"
echo "   ${MINIKUBE_IP}   ecommerce.local grafana.local"
echo ""
echo " Access URLs:"
echo "   E-Commerce : https://ecommerce.local"
echo "   Grafana    : https://grafana.local"
echo "   Prometheus : kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090"
echo ""
echo " Grafana credentials:"
echo "   User     : admin"
echo "   Password : ChangeMe!Grafana2024  (update grafana-values.yaml)"
echo ""
echo " Useful commands:"
echo "   kubectl get all -n ecommerce"
echo "   kubectl get all -n monitoring"
echo "   kubectl top pods -n ecommerce"
echo "======================================================"
