{{/* Expand the chart name. */}}
{{- define "transcriber.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Create a release-scoped name. */}}
{{- define "transcriber.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/* Create a chart label that is safe for Kubernetes labels. */}}
{{- define "transcriber.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels. */}}
{{- define "transcriber.labels" -}}
helm.sh/chart: {{ include "transcriber.chart" . }}
{{ include "transcriber.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels. */}}
{{- define "transcriber.selectorLabels" -}}
app.kubernetes.io/name: {{ include "transcriber.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Name of the chart-managed application ConfigMap. */}}
{{- define "transcriber.configMapName" -}}
{{- printf "%s-config" (include "transcriber.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Name of the chart-managed data PVC. */}}
{{- define "transcriber.persistenceClaimName" -}}
{{- printf "%s-data" (include "transcriber.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Fail early when the source list is not configured. */}}
{{- define "transcriber.validateSources" -}}
{{- if .Values.sources.existingConfigMap }}
{{- if not .Values.sources.existingConfigMapKey }}
{{- fail "sources.existingConfigMapKey must be set when sources.existingConfigMap is used" }}
{{- end }}
{{- else if not .Values.sources.entries }}
{{- fail "configure at least one sources.entries item or set sources.existingConfigMap" }}
{{- end }}
{{- if and .Values.git.enabled (not .Values.git.remote) }}
{{- fail "git.remote must be set when git.enabled is true" }}
{{- end }}
{{- if and .Values.git.existingSecret (not .Values.git.tokenKey) }}
{{- fail "git.tokenKey must be set when git.existingSecret is used" }}
{{- end }}
{{- end }}
