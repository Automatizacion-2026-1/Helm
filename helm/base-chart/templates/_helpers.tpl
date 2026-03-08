# helm/base-chart/templates/_helpers.tpl

{{/* Define el nombre base */}}
{{- define "base-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Define el nombre completo para los recursos */}}
{{- define "base-chart.fullname" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Etiquetas estándar que exige la industria */}}
{{- define "base-chart.labels" -}}
helm.sh/chart: {{ include "base-chart.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "base-chart.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Etiquetas estrictas para el selector de red */}}
{{- define "base-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "base-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}