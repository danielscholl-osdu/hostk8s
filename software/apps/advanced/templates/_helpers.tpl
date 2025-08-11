{{/*
Expand the name of the chart.
*/}}
{{- define "advanced.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "advanced.fullname" -}}
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
{{- define "advanced.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "advanced.labels" -}}
helm.sh/chart: {{ include "advanced.chart" . }}
{{ include "advanced.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
hostk8s.app: advanced
{{- end }}

{{/*
Selector labels
*/}}
{{- define "advanced.selectorLabels" -}}
app.kubernetes.io/name: {{ include "advanced.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Frontend component selector labels
*/}}
{{- define "advanced.frontendSelectorLabels" -}}
{{ include "advanced.selectorLabels" . }}
app.kubernetes.io/component: frontend
{{- end }}

{{/*
Backend component selector labels
*/}}
{{- define "advanced.backendSelectorLabels" -}}
{{ include "advanced.selectorLabels" . }}
app.kubernetes.io/component: backend
{{- end }}
