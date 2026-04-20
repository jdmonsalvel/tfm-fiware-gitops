{{- define "orion-ld.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "orion-ld.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "orion-ld.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: tfm-fiware-gitops
{{- end }}

{{- define "orion-ld.selectorLabels" -}}
app.kubernetes.io/name: orion-ld
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
