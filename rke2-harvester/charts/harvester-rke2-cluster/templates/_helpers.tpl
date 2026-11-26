{{- define "hrc.clusterName" -}}
{{- required "cluster.name est obligatoire" .Values.cluster.name -}}
{{- end -}}

{{- define "hrc.machineConfigName" -}}
{{- printf "%s-%s" (include "hrc.clusterName" .root) .pool.name -}}
{{- end -}}

{{- define "hrc.cloudProviderSecret" -}}
{{- default (printf "%s-cloudprovider" (include "hrc.clusterName" .)) .Values.cloudProviderConfigSecretName -}}
{{- end -}}
