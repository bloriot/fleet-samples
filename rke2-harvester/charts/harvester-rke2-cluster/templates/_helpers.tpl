{{- define "hrc.machineConfigName" -}}
{{- printf "%s-%s" .root.Values.cluster.name .pool.name -}}
{{- end -}}

{{- define "hrc.cloudProviderSecret" -}}
{{- default (printf "%s-cloudprovider" .Values.cluster.name) .Values.cloudProviderConfigSecretName -}}
{{- end -}}
