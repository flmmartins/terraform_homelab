variable "chart_version" {
  description = "Metric Server Chart Version. Versions can be found in https://github.com/kubernetes-sigs/metrics-server/blob/master/charts/metrics-server/CHANGELOG.md"
  default     = "3.14.0"
}

resource "helm_release" "this" {
  name             = "metrics-server"
  namespace        = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server"
  create_namespace = true
  version          = var.chart_version
  chart            = "metrics-server"
  max_history      = 10
}
