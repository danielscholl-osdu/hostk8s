{{/*
Expand the name of the chart.
*/}}
{{- define "helm-sample.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "helm-sample.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "helm-sample.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "helm-sample.labels" -}}
helm.sh/chart: {{ include "helm-sample.chart" . }}
{{ include "helm-sample.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
hostk8s.app: helm-sample
{{- end }}

{{/*
Selector labels
*/}}
{{- define "helm-sample.selectorLabels" -}}
app.kubernetes.io/name: {{ include "helm-sample.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component selector labels
*/}}
{{- define "helm-sample.componentSelectorLabels" -}}
{{ include "helm-sample.selectorLabels" . }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
