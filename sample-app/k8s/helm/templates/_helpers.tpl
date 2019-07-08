{{- define "app.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{- define "app.fullname" -}}
{{ if (ne .Values.app.env "production") -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Release.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" $name .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Values.app.env | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}


{{- define "ingress.host" -}}
{{ if (ne .Values.app.env "production") -}}
{{ .Release.Name }}-{{ .Values.app.name }}.
{{- end -}}{{ .Values.ingress.domain }}
{{- end -}}

{{- define "ingress.shortHost" -}}
{{ if (ne .Values.app.env "production") -}}
{{ .Release.Name | trunc 15 | trimSuffix "-"}}-{{ .Values.app.name }}.
{{- end -}}{{ .Values.ingress.domain }}
{{- end -}}

s
{{- define "app.labels" -}}
app: {{ template "app.name" . }}
env: {{ .Values.app.env }}
component: {{ .Values.app.component }}
version: {{ .Values.image.tag }}
{{- end -}}
