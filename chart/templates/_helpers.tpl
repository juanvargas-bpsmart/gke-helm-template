{{- define "app.labels" -}}
app: {{ .Values.config.name }}
app.kubernetes.io/name: {{ .Values.config.name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: Helm
app.kubernetes.io/version: {{ .Chart.Version }}
app.kubernetes.io/part-of: {{ .Values.config.partOf | default .Release.Name }}
{{- end -}}
