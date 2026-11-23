{{- define "tenant.namespace" -}}
tenant-{{ .Values.name }}
{{- end }}

{{- define "tenant.labels" -}}
platform.golden-path.io/tenant: {{ .Values.name }}
platform.golden-path.io/tier: {{ .Values.tier }}
platform.golden-path.io/cost-center: {{ .Values.costCenter }}
platform.golden-path.io/llm-enabled: {{ .Values.llm.enabled | quote }}
app.kubernetes.io/managed-by: golden-path-platform
{{- end }}

{{/* Quota per tier. Kept here, not in values, so tenants cannot override it. */}}
{{- define "tenant.tiers" -}}
small:
  requestsCpu: "2"
  requestsMemory: 4Gi
  limitsCpu: "4"
  limitsMemory: 8Gi
  pods: "20"
medium:
  requestsCpu: "4"
  requestsMemory: 8Gi
  limitsCpu: "8"
  limitsMemory: 16Gi
  pods: "50"
large:
  requestsCpu: "8"
  requestsMemory: 16Gi
  limitsCpu: "16"
  limitsMemory: 32Gi
  pods: "100"
{{- end }}
