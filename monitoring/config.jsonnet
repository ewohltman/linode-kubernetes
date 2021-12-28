local kp =
    (import 'kube-prometheus/main.libsonnet') +
    (import 'kube-prometheus/addons/anti-affinity.libsonnet') +
    {
      values+:: {
        common+: {
          namespace: 'monitoring',
        },

        prometheus+:: {
          namespaces+: ['kube-system','monitoring','observability','projectcontour','ephemeral-roles'],
          serviceMonitorEphemeralRoles: {
            apiVersion: 'monitoring.coreos.com/v1',
            kind: 'ServiceMonitor',
            metadata: {
              name: 'ephemeral-roles',
              namespace: 'ephemeral-roles',
            },
            spec: {
              jobLabel: 'app',
              endpoints: [{port: 'http'}],
              selector: {
                matchLabels: {
                  app: 'ephemeral-roles',
                },
              },
            },
          },
        },

        grafana+:: {
          config: { // http://docs.grafana.org/installation/configuration/
            sections: {
              "auth.anonymous": {enabled: true},
            },
          },
          dashboards+:: {  // use this method to import your dashboards to Grafana
            'ephemeral-roles-dashboard.json': (import 'ephemeral-roles-dashboard.json'),
          },
        },

        alertmanager+: {
          config: |||
            global:
              resolve_timeout: 1m
            receivers:
              - name: default-receiver
              - name: pod-bouncer
                webhook_configs:
                  - url: http://pod-bouncer.ephemeral-roles.svc.cluster.local:8080/alert
            route:
              group_by: ['alertname']
              group_wait: 30s
              group_interval: 5m
              repeat_interval: 15m
              receiver: default-receiver
              routes:
                - match_re:
                  alertname: EphemeralRoles-Goroutines
                  receiver: pod-bouncer
          |||,
          },
        },

        prometheusAlerts+:: {
          groups+: [
            {
              name: 'ephemeral-roles',
              rules: [
                {
                  alert: 'EphemeralRoles-Goroutines',
                  expr: 'go_goroutines{namespace="ephemeral-roles",pod=~"ephemeral-roles-.+"} > 100',
                  labels: {
                    severity: 'critical',
                  },
                  annotations: {
                    description: 'This is to alert when the number of goroutines exceeds a threshold.',
                  },
                },
              ],
            },
          ],
        },
      };

{ 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
