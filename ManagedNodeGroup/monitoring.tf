resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  wait             = true
  timeout          = 900
  atomic           = true
  cleanup_on_fail  = true

  # ------------------------------------------------------------------
  # Grafana
  # ------------------------------------------------------------------
  set = [
    {
      name  = "grafana.enabled"
      value = "true"
    },
    {
      name  = "grafana.service.type"
      value = "LoadBalancer"
    },
    {
      name  = "grafana.persistence.enabled"
      value = "true"
    },
    {
      name  = "grafana.persistence.size"
      value = "10Gi"
    },
    # ---------------------------------------------------------------
    # Prometheus
    # ---------------------------------------------------------------
    {
      name  = "prometheus.enabled"
      value = "true"
    },
    {
      name  = "prometheus.prometheusSpec.retention"
      value = "15d"
    },
    {
      name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
      value = "20Gi"
    },
    # ---------------------------------------------------------------
    # Alertmanager
    # ---------------------------------------------------------------
    {
      name  = "alertmanager.enabled"
      value = "true"
    },
    {
      name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
      value = "10Gi"
    },
    # ---------------------------------------------------------------
    # Kubernetes State Metrics
    # ---------------------------------------------------------------
    {
      name  = "kubeStateMetrics.enabled"
      value = "true"
    },
    # ---------------------------------------------------------------
    # Node Exporter
    # ---------------------------------------------------------------
    {
      name  = "nodeExporter.enabled"
      value = "true"
    }
  ]
}