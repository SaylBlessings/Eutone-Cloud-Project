# Eutone Cloud Project — E-Commerce Kubernetes Stack

Production-grade Kubernetes manifests for deploying a containerised e-commerce
application on Minikube, with Prometheus and Grafana monitoring via Helm.

---

## Architecture Overview

```
ecommerce namespace
└── Deployment (ecommerce-app)
    ├── Service (ClusterIP)
    ├── Ingress (NGINX → ecommerce.local)
    ├── HPA (2–10 pods, CPU 60% / Memory 70%)
    ├── PodDisruptionBudget (min 1 available)
    └── NetworkPolicy (deny-all + scoped allows)

monitoring namespace
├── Prometheus  (kube-prometheus-stack via Helm)
├── Grafana     (grafana/grafana via Helm)
├── ServiceMonitor (scrapes /metrics from ecommerce pods)
└── PrometheusRules (alerting: down, crash-loop, CPU, HPA)
```

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Minikube | ≥ 1.32 | https://minikube.sigs.k8s.io/docs/start/ |
| kubectl | ≥ 1.28 | https://kubernetes.io/docs/tasks/tools/ |
| Helm | ≥ 3.12 | https://helm.sh/docs/intro/install/ |
| Docker | ≥ 24 | https://docs.docker.com/get-docker/ |

---

## Quick Start

### 1. Start Minikube

```bash
minikube start --cpus=4 --memory=6g
```

### 2. Configure your image and secrets

Edit `k8s/ecommerce/deployment.yaml` — replace the image:

```yaml
image: your-dockerhub-username/ecommerce-app:latest
```

Edit `k8s/ecommerce/secret.yaml` — replace base64 placeholders:

```bash
echo -n 'your-db-password'    | base64
echo -n 'your-redis-password' | base64
echo -n 'your-jwt-secret'     | base64
```

Edit `k8s/monitoring/grafana-values.yaml` — change the admin password:

```yaml
adminPassword: "YourSecurePassword"
```

### 3. Deploy the full stack

```bash
bash k8s/install.sh
```

### 4. Add local DNS entries

```bash
echo "$(minikube ip)  ecommerce.local grafana.local" | sudo tee -a /etc/hosts
```

---

## Access

| Service | URL | Credentials |
|---|---|---|
| E-Commerce App | https://ecommerce.local | — |
| Grafana | https://grafana.local | admin / *see grafana-values.yaml* |
| Prometheus | `kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090` then http://localhost:9090 | — |

---

## Repository Structure

```
k8s/
├── install.sh                              One-shot Minikube installer
├── namespaces/
│   └── namespaces.yaml                     ecommerce + monitoring namespaces
├── ecommerce/
│   ├── configmap.yaml                      Non-sensitive app config
│   ├── secret.yaml                         Credentials (base64 — replace before deploy)
│   ├── deployment.yaml                     Deployment + ServiceAccount
│   ├── service.yaml                        ClusterIP service
│   ├── hpa.yaml                            HorizontalPodAutoscaler
│   ├── pdb.yaml                            PodDisruptionBudget
│   ├── ingress.yaml                        NGINX Ingress
│   └── networkpolicy.yaml                  Network isolation rules
└── monitoring/
    ├── prometheus-values.yaml              kube-prometheus-stack Helm values
    ├── grafana-values.yaml                 Grafana Helm values + dashboards
    ├── servicemonitor-ecommerce.yaml       Auto-scrape ecommerce /metrics
    └── alerting-rules.yaml                PrometheusRules
```

---

## Design Decisions

| Pillar | Implementation |
|---|---|
| **Scalability** | HPA scales 2→10 replicas on CPU/memory pressure; topology spread across nodes |
| **Reliability** | PDB guarantees min 1 pod; `maxUnavailable: 0` rolling updates; liveness/readiness/startup probes; 60s graceful shutdown |
| **Security** | Non-root container, read-only root filesystem, all Linux capabilities dropped, `automountServiceAccountToken: false`, deny-all NetworkPolicy, NGINX rate limiting |
| **Monitoring** | Prometheus scrapes every 30s; Grafana pre-loaded with cluster/node/NGINX dashboards; alerts fire on app-down, crash-loop, high resource usage, HPA saturation |

---

## Useful Commands

```bash
# Check all resources
kubectl get all -n ecommerce
kubectl get all -n monitoring

# Watch HPA scaling
kubectl get hpa -n ecommerce -w

# View pod logs
kubectl logs -l app=ecommerce -n ecommerce --tail=100

# Resource usage
kubectl top pods -n ecommerce
kubectl top nodes

# Restart deployment
kubectl rollout restart deployment/ecommerce-app -n ecommerce

# Helm releases
helm list -A
```

---

## Alerting Rules

| Alert | Condition | Severity |
|---|---|---|
| `EcommerceAppDown` | No pods reachable for > 1 min | Critical |
| `EcommercePodCrashLooping` | Restart rate > 0 for 5 min | Warning |
| `EcommerceHighCPU` | CPU > 80% of limit for 5 min | Warning |
| `EcommerceHighMemory` | Memory > 80% of limit for 5 min | Warning |
| `EcommerceHPAMaxedOut` | HPA at max replicas for 10 min | Warning |

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-change`
3. Commit your changes
4. Open a pull request targeting `main`

---

## License

<!-- Add your licence here e.g. MIT, Apache 2.0 -->
