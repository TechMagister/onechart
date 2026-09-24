---
title: 'OneChart Reference'
description: |
  OneChart is a generic Helm chart for your application deployments.
---

> One chart to rule them all

A generic Helm chart for your application deployments. Because no one can remember the Kubernetes yaml syntax.

## Getting Started

OneChart is a generic Helm Chart for web applications. The idea is that most Kubernetes manifest look alike, only very few parts actually change.

Add the OneChart Helm repository:

```
helm repo add onechart https://techmagister.github.io/onechart
```

Set your image name and version, the boilerplate is generated.

```
helm template my-release onechart/onechart \
  --set image.repository=nginx \
  --set image.tag=1.19.3
```

The example below deploys your application image, sets environment variables and configures the Kubernetes Ingress domain name:

```
helm repo add onechart https://techmagister.github.io/onechart
helm template my-release onechart/onechart -f values.yaml

# values.yaml
image:
  repository: my-app
  tag: fd803fc
vars:
  VAR_1: "value 1"
  VAR_2: "value 2"
ingress:
  annotations:
    kubernetes.io/ingress.class: nginx
  host: my-app.mycompany.com
```

## Kubernetes Recommended Labels

OneChart supports the optional `component` and `partOf` values. They are rendered as the Kubernetes [recommended labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/) `app.kubernetes.io/component` and `app.kubernetes.io/part-of`:

```
nameOverride: assistant-ia
component: api
partOf: assistant-ia
```

`component` is the name of the component within the architecture (for example `api`, `worker` or `database`), while `partOf` is the name of a higher level application this one is part of (for example `assistant-ia`).

Both labels are added to the `metadata.labels` of every generated resource that carries the chart's common labels (Deployment, Service, Ingress, ServiceMonitor, PrometheusRule, and any other object using the shared `helm-chart.labels` helper).

These labels are purely informational. They are **not** part of any selector: `Deployment.spec.selector.matchLabels`, `Service.spec.selector` and the other selectors keep using `app.kubernetes.io/name` and `app.kubernetes.io/instance` only. Adding or removing `component`/`partOf` after a release therefore never desynchronizes the selectors and cannot orphan a Service. They are meant for observability, global selection (for example `kubectl get all -l app.kubernetes.io/part-of=assistant-ia`) and resource organization.

Both values default to `""`: when they are not set, no `component` or `part-of` label is rendered, and the generated manifests are unchanged.

## Naming

Resource names are always derived from the Helm release name: `helm template my-release …` produces a `Deployment` and a `Service` named `my-release`.

`nameOverride` changes the `app.kubernetes.io/name` label, and the same label in the selectors, from the chart name to a custom name:

```
nameOverride: assistant-ia
```

This is useful when you deploy several OneChart releases that belong to the same application and want them grouped under one name. `fullnameOverride` is accepted for compatibility with common Helm charts, but in the current version of OneChart it does not change the generated resource names.

See the [Kubernetes Recommended Labels](#kubernetes-recommended-labels) section for `component` and `partOf`.

## Deploying an Image

OneChart settings for deploying the Nginx image:

```
image:
  repository: nginx
  tag: 1.19.3
```

The image pull policy defaults to `IfNotPresent`. Set `pullPolicy` explicitly when your tag is mutable or when you want Kubernetes to always pull:

```
image:
  repository: nginx
  tag: 1.19.3
  pullPolicy: Always
```

Check the Kubernetes manifest:

```
cat << EOF > values.yaml
image:
  repository: nginx
  tag: 1.19.3
EOF

helm template my-release onechart/onechart -f values.yaml
```

## Deploying a Private Image

OneChart settings for deploying `my-web-app` image from Amazon ECR:

```
image:
  repository: aws_account_id.dkr.ecr.region.amazonaws.com/my-web-app
  tag: x.y.z

imagePullSecrets:
  - regcred
```

Check the Kubernetes manifest:

```
cat << EOF > values.yaml
image:
  repository: aws_account_id.dkr.ecr.region.amazonaws.com/my-web-app
  tag: x.y.z

imagePullSecrets:
 - regcred
EOF

helm template my-release onechart/onechart -f values.yaml
```

Image pull credentials must be set up in the cluster.

The `regcred` image pull credentials must be set up in the cluster. See how in [Kubernetes documentation](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/).

## Environment Variables

OneChart settings for setting environment variables:

```
image:
  repository: nginx
  tag: 1.19.3

vars:
  VAR_1: 'value 1'
  VAR_2: 'value 2'
```

Check the Kubernetes manifest:

```
cat << EOF > values.yaml
image:
  repository: nginx
  tag: 1.19.3

vars:
  VAR_1: "value 1"
  VAR_2: "value 2"
EOF

helm template my-release onechart/onechart -f values.yaml
```

### Using existing ConfigMaps and Secrets

To load all keys of existing `ConfigMap` or `Secret` objects as environment variables, without copying them into the values file:

```
existingConfigMaps:
  - name: my-config
    optional: false

existingSecrets:
  - name: my-secret
    optional: true
```

Each entry is rendered as an `envFrom` reference on the application container, the sidecar and the init containers.

## Secrets

### Referencing Secret by Convention

Secrets demand special handling, and often they are stored, managed and configured in a workflow that is adjacent to application deployment.

Therefore, OneChart will not generate a Kubernetes `Secret` object by default, but it can reference one. Using the `secretEnabled: true` field, OneChart will look for a secret named exactly as your release.

```
image:
  repository: nginx
  tag: 1.19.3

secretEnabled: true
```

How the Kubernetes `Secret` object gets on the cluster, remains your task.

#### Creating Secrets

For testing purposes you can put the secret in your cluster with this command:

```
kubectl create secret generic my-release \
  --from-literal=SECRET1="my secret" \
  --from-literal=SECRET2="another secret"
```

Given that you called your release `my-release`.

### Referencing Secret by Name

You may use a secret with a custom name, by using the `secretName` field:

```
image:
  repository: nginx
  tag: 1.19.3

secretName: my-custom-secret
```

### Mounting Secrets as Files

You may use OneChart's `fileSecrets` feature to provide your application with long form secrets: SSH keys or json files that are typically used as service account keys on Google Cloud.

```
image:
  repository: nginx
  tag: 1.19.3

fileSecrets:
  - name: google-account-key
    path: /google-account-key
    secrets:
      key.json: supersecret
      another.json: |
        this
        is
        a
        multiline
        secret
```

- The above snippet will create a Kubernetes Secret object with two entries
- This secret is mounted to the `/google-account-key` and produce two files: `key.json` and `another.json`

An advanced version of mounting file secrets into pods, and doing it in a secure way is to use the `sealedFileSecrets` field. The behavior is identical to `fileSecrets`, it just uses a sealed secret as the content of the file:

```
image:
  repository: nginx
  tag: 1.19.3

sealedFileSecrets:
  - name: google-account-key
    path: /google-account-key
    filesToMount:
      - name: key.json
        source: AgA/7BnNhSkZAzbMqxMDidxK[...]
```

If the file secret already exists in the cluster, reference it with `existingFileSecrets`. OneChart mounts it read-only and does not create the `Secret`:

```
existingFileSecrets:
  - name: my-existing-secret
    path: /secrets
    subPath: key.json
```

### Using Encrypted Secret Values

OneChart also has a secret workflow to keep secrets in git in an encrypted form. This requires that you have [Bitnami's Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) configured in your cluster.

You can ease the management of `SealedSecret` objects with OneChart's `sealedSecrets` field:

```
image:
  repository: nginx
  tag: 1.19.3

sealedSecrets:
  secret1: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEq...
  secret2: ewogICJjcmVk...
```

You need to put already sealed values in the values.yaml file. To seal your secrets, use [Sealed Secret's raw mode](https://github.com/bitnami-labs/sealed-secrets#raw-mode-experimental).

Sealing string passwords:

```
echo -n mysupersecretstring | kubeseal  \
  --raw --scope cluster-wide \
  --controller-namespace=infrastructure \
  --from-file=/dev/stdin
```

Sealing entire files:

```
kubeseal \
  --raw --scope cluster-wide \
  --controller-namespace=infrastructure \
  --from-file=/home/laszlo/nats-testing-ca.crt
```

## Domain Names

OneChart generates a Kubernetes ingress resource for the Nginx ingress controller with the following settings:

```
image:
  repository: my-app
  tag: 1.0.0

ingress:
  annotations:
    kubernetes.io/ingress.class: nginx
  host: chart-example.local
```

Check the Kubernetes manifest:

```
cat << EOF > values.yaml
image:
  repository: my-app
  tag: 1.0.0

ingress:
  annotations:
    kubernetes.io/ingress.class: nginx
  host: my-app.mycompany.com
EOF

helm template my-app onechart/onechart -f values.yaml
```

Additional optional fields:

| Field                                       | Description                                                                                                      |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `ingress.ingressClassName`                  | Sets `spec.ingressClassName`, the modern replacement for the `kubernetes.io/ingress.class` annotation.           |
| `ingress.path`                              | Path served by the ingress. Defaults to `/`.                                                                     |
| `ingress.pathType`                          | Kubernetes path type (`Prefix`, `Exact` or `ImplementationSpecific`). Defaults to `Prefix`.                      |
| `ingress.secretName`                        | Name of the TLS secret used when `tlsEnabled` is `true`. Defaults to `tls-<release name>`.                       |
| `ingress.nginxBasicAuth.user` / `.password` | Protects the ingress with Nginx basic authentication. OneChart generates a `<release name>-basic-auth` `Secret`. |

The Nginx ingress controller must be set up in your cluster for this setting to work. For other ingress controllers, please use the matching annotation.

### HTTPS

To reference a TLS secret use the `tlsEnabled` field. The deployment will point to a secret named: `tls-$.Release.Name`

```
cat << EOF > values.yaml
image:
  repository: my-app
  tag: 1.0.0

ingress:
  annotations:
    kubernetes.io/ingress.class: nginx
  host: my-app.mycompany.com
  tlsEnabled: true
EOF

helm template my-app onechart/onechart -f values.yaml
```

### HTTPS - Let's Encrypt

If your cluster has Cert Manager running, you should add Cert Manager's annotation to have automated cert provisioning.

```
# values.yaml
image:
  repository: my-app
  tag: 1.0.0

ingress:
  annotations:
    kubernetes.io/ingress.class: nginx
+   cert-manager.io/cluster-issuer: letsencrypt
  host: my-app.mycompany.com
  tlsEnabled: true

```

### Listening on multiple domains

```
cat << EOF > values.yaml
image:
  repository: my-app
  tag: 1.0.0

ingresses:
  - host: one.mycompany.com
    annotations:
      kubernetes.io/ingress.class: nginx
    tlsEnabled: true
  - host: two.mycompany.com
    annotations:
      kubernetes.io/ingress.class: nginx
    tlsEnabled: true
EOF

helm template my-app onechart/onechart -f values.yaml
```

### Multiple paths

A single host can serve multiple paths with `ingress.paths`:

```
ingress:
  host: my-app.mycompany.com
  paths:
    - path: /
      pathType: Prefix
    - path: /api
      pathType: Prefix
```

### Basic Authentication

To protect the ingress with Nginx basic authentication, set a username and a password:

```
ingress:
  host: my-app.mycompany.com
  nginxBasicAuth:
    user: admin
    password: secret
```

OneChart generates a `Secret` named `<release name>-basic-auth` and configures the Nginx `auth-type`, `auth-secret` and `auth-realm` annotations on the ingress.

## Service

OneChart generates a `Service` that targets the application port. The following values control it.

### Ports

`containerPort` is the port your application listens on (default `80`). Use `svcPort` to expose a different port on the `Service`, and `ports` to declare more than one port:

```
ports:
  - name: http
    containerPort: 8080
    svcPort: 80
  - name: admin
    containerPort: 9090
    nodePort: 30090
```

When `ports` is set it replaces the default single `http` port on both the container and the `Service`. Each entry accepts `name`, `containerPort`, `svcPort`, `nodePort` and `protocol` (`TCP` by default). The `Service` port falls back to the container port when `svcPort` is omitted.

### Service types

By default the `Service` is a `ClusterIP`. Switch to `NodePort` or `LoadBalancer` with:

```
# Expose the service on a static port on every node
nodePortEnabled: true
nodePort: 30080

# Or provision a cloud load balancer
loadbalancerEnabled: true
```

### Sticky sessions

Set `stickySessions: true` to set `externalTrafficPolicy: Local` and a client-IP session affinity timeout of three hours (10800 seconds):

```
stickySessions: true
```

### Service annotations

`serviceAnnotations` adds arbitrary annotations to the `Service`:

```
serviceAnnotations:
  my-annotation: my-value
```

### Service catalog metadata

The following optional values describe the service and are rendered as `v1alpha1.opensca.dev/*` annotations on the `Service`, so catalog and observability tools can discover it:

| Value                | Annotation                           |
| -------------------- | ------------------------------------ |
| `serviceName`        | `v1alpha1.opensca.dev/name`          |
| `serviceDescription` | `v1alpha1.opensca.dev/description`   |
| `ownerName`          | `v1alpha1.opensca.dev/owner.name`    |
| `ownerIm`            | `v1alpha1.opensca.dev/owner.im`      |
| `documentation`      | `v1alpha1.opensca.dev/documentation` |
| `logs`               | `v1alpha1.opensca.dev/logs`          |
| `metrics`            | `v1alpha1.opensca.dev/metrics`       |
| `issues`             | `v1alpha1.opensca.dev/issues`        |
| `traces`             | `v1alpha1.opensca.dev/traces`        |

```
serviceName: cart-backend
serviceDescription: "Backend to manage shopping cart state, written in Go"
ownerName: backend-team
ownerIm: "#backend-team"
documentation: https://confluence.mycompany.com/cart-backend
logs: https://grafana.mycompany.com/logs
metrics: https://grafana.mycompany.com/cart-dashboard
issues: https://jira.mycompany.com/cart-backend
traces: https://jaeger.mycompany.com/cart-dashboard
```

## Volumes

OneChart settings for mounting volumes:

```
image:
  repository: nginx
  tag: 1.19.3

volumes:
  - name: data
    path: /data
    size: 10Gi
    storageClass: default
```

Check the Kubernetes manifest:

```
cat << EOF > values.yaml
image:
  repository: nginx
  tag: 1.19.3

volumes:
  - name: data
    path: /data
    size: 10Gi
    storageClass: default
EOF

helm template my-release onechart/onechart -f values.yaml
```

### Using Existing `PersistentVolumeClaims`

If for some reason you want to use an existing `PersistentVolumeClaim`, use the following syntax:

```
cat << EOF > values.yaml
image:
  repository: nginx
  tag: 1.19.3

volumes:
  - name: data
    path: /data
    existingClaim: my-static-claim
EOF

helm template my-release onechart/onechart -f values.yaml
```

### About Volumes

OneChart generates a `PersistentVolumeClaim` with this configuration and mounts it to the given path.

You have to know what `storageClass` is supported in your cluster.

- On Google Cloud, `standard` gets you disk.
- On Azure, `default` gets you a normal block storage.
- Use `do-block-storage` for Digital Ocean.

### Volume types and options

Besides persistent volumes, a `volumes` entry can describe other Kubernetes volume sources:

| Field                      | Description                                                                          |
| -------------------------- | ------------------------------------------------------------------------------------ |
| `name`                     | Volume name, also used in the generated resource name.                               |
| `path`                     | Mount path inside the container.                                                     |
| `size`                     | Requested storage size for the generated `PersistentVolumeClaim`. Defaults to `1Gi`. |
| `storageClass`             | `storageClassName` for the generated claim.                                          |
| `accessMode`               | Access mode of the generated claim. Defaults to `ReadWriteOnce`.                     |
| `existingClaim`            | Use an existing `PersistentVolumeClaim` instead of creating one.                     |
| `pvcAnnotations`           | Annotations added to the generated `PersistentVolumeClaim`.                          |
| `emptyDir`                 | Mount an `emptyDir` volume.                                                          |
| `hostPath.path` / `.type`  | Mount a path from the host.                                                          |
| `existingConfigMap`        | Mount an existing `ConfigMap` as a volume.                                           |
| `existingSecret`           | Mount an existing `Secret` as a volume.                                              |
| `fileName` / `fileContent` | Generate a `ConfigMap` with a single file and mount it.                              |
| `subPath`                  | Mount a single key of the volume instead of the whole volume.                        |

```
volumes:
  - name: cache
    path: /cache
    emptyDir: true

  - name: host-data
    path: /host-data
    hostPath:
      path: /var/data
      type: Directory

  - name: config
    path: /etc/my-app
    fileName: config.yaml
    fileContent: |
      key: value
```

### Init volume name prefixes

Volumes whose name starts with `init-` are mounted only in the init containers. Volumes whose name starts with `shared-` are mounted both in the init containers and in the application container. This lets an init container prepare data for the application to consume.

## Healthcheck

You can set a Kubernetes Readiness probe that determines whether your app is healthy and if it should receive traffic.

Enable it with:

```
probe:
  enabled: false
  path: "/"
```

Check the Kubernetes manifest:

```
cat << EOF > values.yaml
probe:
  enabled: false
  path: "/"
EOF

helm template my-release onechart/onechart -f values.yaml
```

### Finetuning

You can further tune the frequency and thresholds of the probe with:

```
probe:
  enabled: false
  path: '/'
  settings:
    initialDelaySeconds: 0
    periodSeconds: 10
    successThreshold: 1
    timeoutSeconds: 3
    failureThreshold: 3
```

| Setting             | Description                                                                                                                                     |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| initialDelaySeconds | Number of seconds after the container has started before the probes is initiated.                                                               |
| periodSeconds       | How often (in seconds) to perform the probe.                                                                                                    |
| successThreshold    | Minimum consecutive successes for the probe to be considered successful after having failed.                                                    |
| timeoutSeconds      | Number of seconds after which the probe times out.                                                                                              |
| failureThreshold    | When a probe fails, Kubernetes will tries this many times before giving up. Giving up the pod will be marked Unready and won't get any traffic. |

### Liveness probe

The liveness probe restarts the container when it becomes unresponsive. It uses the same settings as the readiness probe:

```
livenessProbe:
  enabled: true
  path: "/healthz"
  settings:
    initialDelaySeconds: 5
    periodSeconds: 10
    failureThreshold: 3
```

Before enabling a liveness probe, consider [the caveats](https://srcco.de/posts/kubernetes-liveness-probes-are-dangerous.html).

## High-Availability

OneChart makes your applications highly available as long as you set the replicas more than 1.

```
replicas: 2
```

When the replica count is higher than one, OneChart creates a `PodDisruptionBudget` so that node maintenance leaves at least one instance running:

```
replicas: 2
podDisruptionBudgetEnabled: true   # default true
```

You can also spread the pods across nodes by enabling `spreadAcrossNodes`, which adds a required pod anti-affinity on `kubernetes.io/hostname`:

```
replicas: 2
spreadAcrossNodes: true   # default false
```

Set `podDisruptionBudgetEnabled: false` to skip the `PodDisruptionBudget`, or `spreadAcrossNodes: false` to skip the anti-affinity.

## Scheduling

Schedule the pods with the standard Kubernetes scheduling constraints:

```
nodeSelector:
  disktype: ssd

tolerations:
  - key: dedicated
    operator: Equal
    value: my-app
    effect: NoSchedule

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: topology.kubernetes.io/zone
              operator: In
              values:
                - eu-west-1a
```

`affinity` is merged with the pod anti-affinity generated by `spreadAcrossNodes`.

## Custom Command

OneChart settings for overriding the default command to run:

```
image:
  repository: debian
  tag: stable-slim

command: |
  while true; do date; sleep 2; done
```

Check the Kubernetes manifest:

```
cat << EOF > values.yaml
image:
  repository: debian
  tag: stable-slim

command: |
  while true; do date; sleep 2; done
EOF

helm template my-release onechart/onechart -f values.yaml
```

### Using bash

```
cat << EOF > values.yaml
image:
  repository: debian
  tag: stable-slim

command: |
  while true; do date; sleep 2; done
shell: "/bin/bash"
EOF

helm template my-release onechart/onechart -f values.yaml
```

### Running a Command in Alpine Linux

```
cat << EOF > values.yaml
image:
  repository: alpine
  tag: 3.12

command: |
  while true; do date; sleep 2; done
shell: "/bin/ash"
EOF

helm template my-release onechart/onechart -f values.yaml
```

## Pod Labels and Annotations

`podLabels` and `podAnnotations` add labels and annotations to the pod template (not to the Deployment itself):

```
podLabels:
  team: backend
  environment: production

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
```

## Init Containers

`initContainers` runs one or more containers before the application container starts:

```
initContainers:
  - name: migrate
    image: my-app-migrations
    tag: "1.0.0"
    imagePullPolicy: IfNotPresent
    command: "./migrate up"
    securityContext:
      runAsNonRoot: true
```

Each init container accepts `name`, `image`, `tag`, `imagePullPolicy` (default `IfNotPresent`), `command` and `securityContext`. Init containers inherit the `envFrom` references (`vars`, `secretEnabled`, `secretName`, `sealedSecrets`, `existingSecrets`, `existingConfigMaps`) and can mount volumes whose name starts with `init-` or `shared-`.

## Security Context

For security reasons, if your application doesn't require root access and writing to the root file system, we recommend you to set `readOnlyRootFilesystem: true` and `runAsNonRoot: true`.

By default, OneChart sets `fsGroup: 999` in the pod security context. This is useful for applications that need to write to volumes and need a specific group ID for file permissions.

**Example of setting security context for containers**

```
# values.yaml
securityContext:
  readOnlyRootFilesystem: true
  runAsNonRoot: true
```

**Example of setting security context for init containers**

```
# values.yaml
initContainers:
- name: test
  image: test:test
  securityContext:
    readOnlyRootFilesystem: true
    runAsNonRoot: true
```

## Resources

```
cat << EOF > values.yaml
image:
  repository: debian
  tag: stable-slim

resources:
  limits:
    cpu: "2000m"
    memory: "2000Mi"
  requests:
    cpu: "200m"
    memory: "500Mi"
EOF

helm template my-release onechart/onechart -f values.yaml
```

### Ignoring resources

Set `resources.ignore: true` to omit the `resources` block entirely, or `resources.ignoreLimits: true` to render only the requests and drop the limits:

```
resources:
  ignore: true
```

```
resources:
  ignoreLimits: true
  requests:
    cpu: "200m"
    memory: "500Mi"
  limits:
    cpu: "2000m"
    memory: "2000Mi"
```

## Cron Job

This section applies to the separate `onechart/cron-job` chart, not to `onechart/onechart`.

OneChart settings for deploying a cron job:

```
image:
  repository: debian
  tag: stable-slim

schedule: '0 1 0 0 0'
command: |
  echo "hello"
```

Check the Kubernetes manifest:

```
cat << EOF > values.yaml
image:
  repository: debian
  tag: stable-slim

schedule: "*/1 * * * *"
command: |
  echo "hello"
EOF

helm template my-release onechart/cron-job -f values.yaml
```

## Service Monitor

If the [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator) is installed, set `monitor.enabled: true` to generate a `ServiceMonitor` that scrapes your application metrics:

```
monitor:
  enabled: true
  path: /metrics        # default /metrics
  portName: http        # port to scrape; defaults to the first declared port
  scheme: http          # default http
  scrapeTimeout: 10s    # optional
```

The `ServiceMonitor` selects the `Service` of this release by its labels and scrapes it in the release namespace.

## Prometheus Monitoring Rules

This section shows how you can add a `PrometheusRule` to your app deployment.

This is a feature only supported by the [kube-stack-prometheus stack (formerly known as the Prometheus Operator)](https://github.com/prometheus-operator/kube-prometheus).

The following Prometheus rule alerts if a pod is crash-looping:

```
# values.yaml
image:
  repository: nginx
  tag: 1.19.3

prometheusRules:
  - name: KubePodCrashLooping
    message: "Pod {{ $labels.namespace }}/{{ $labels.pod }} ({{ $labels.container }}) is restarting {{ printf \"%.2f\" $value }} times / 5 minutes."
    runBookURL: myrunbook.com
    expression: "rate(kube_pod_container_status_restarts_total{job=\"kube-state-metrics\", namespace=~\"{{ $targetNamespace }}\"}[15m]) * 60 * 5 > 0"
    for: 1h
    labels:
      severity: critical

helm template my-release onechart/onechart -f values.yaml
```

## Logging

For the [logging operator](https://github.com/kube-logging/logging-operator), OneChart can generate a `logging.banzaicloud.io/v1beta1` `Flow` resource for the logs of your release.

The `match` section is managed automatically: it selects the pods of your release based on the `app.kubernetes.io/name` and `app.kubernetes.io/instance` labels OneChart puts on the deployment pods. You only have to configure the outputs and the optional filters.

```
# values.yaml
image:
  repository: nginx
  tag: 1.19.3

logging:
  framework: slog_json
  globalOutputRefs:
    - loki-output
  localOutputRefs:
    - my-local-output
  filters:
    - tag_normaliser: {}
```

When `framework` is set to `slog_json`, OneChart adds a `parser` filter that decodes the JSON `message` field emitted by the Go standard library `slog` JSON handler, together with a `record_transformer` tagging the logs with `log_type: application`, `language: go` and `framework: slog`. Your additional `filters` are appended after those two.

Check the Kubernetes manifest:

```sh
helm template my-release onechart/onechart -f values.yaml
```

## Attaching a Sidecar

This section shows how you can add a sidecar container.

```
sidecar:
  repository: debian
  tag: stable-slim
  shell: "/bin/bash"
  command: "while true; do sleep 30; done;"
```

The sidecar is named `<release name>-sidecar`, uses the container `securityContext`, and receives the same environment references and volume mounts as the application container.

Check the Kubernetes manifest:

```
helm template my-release onechart/onechart -f values.yaml
```

## Attaching a Sidecar For Debugging

This section shows how you can add a sidecar container with debug tools installed.

The debug sidecar container will have access to the same resources as your app container, so you don't have to inflate your app container with debug tools.

The following example adds a default debug container (a debian image) to your deployment, and you can verify that this container will have access to the defined volume.

```
sidecar:
  repository: debian
  tag: stable-slim
  shell: '/bin/bash'
  command: 'while true; do sleep 30; done;'

volumes:
  - name: data
    path: /data
    size: 1Gi
    storageClass: local-path
```

Check the Kubernetes manifest:

```
helm template my-release onechart/onechart -f values.yaml
```

## Extra Manifests

`extraDeploy` renders arbitrary Kubernetes manifests verbatim, for resources OneChart does not model. The string is templated, so Helm expressions work inside it:

```
extraDeploy: |
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: my-extra-config
  data:
    key: value
```

## Git Metadata

OneChart can stamp the generated resources with the git revision they were built from:

| Value           | Annotations                                                                                                                                                                                                     |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `gitSha`        | `git-sha` and `v1alpha1.opensca.dev/version.sha` on the `Deployment`, `Service`, `Ingress` and `ServiceMonitor`.                                                                                                |
| `gitBranch`     | `git-branch` and `v1alpha1.opensca.dev/version.branch` on the `Deployment` and `Service`.                                                                                                                       |
| `gitRepository` | `git-repository` on the pod template, `Service`, `Ingress` and `ServiceMonitor`; `v1alpha1.opensca.dev/vcs.owner` and `v1alpha1.opensca.dev/vcs.name` (derived by splitting the value on `/`) on the `Service`. |

```
gitSha: 4c1fe46
gitBranch: main
gitRepository: my-org/my-app
```

## Supporting Any Kubernetes Field

Helm charts can be limiting. If OneChart did not template a particular Kubernetes yaml field, you have to reach for post-processing tools.

To bridge this gap in Helm, we provide the following mechanism.

### Example: Setting `hostNetwork`

The `hostNetwork` field is not templated in OneChart. Still, if you set the setting as seen below, OneChart will merge the hostNetwork field onto `.spec.template.spec` of the Deployment resource. Practically you can set any unimplemented field on the pod specification. Just add it to your values file under `podSpec`.

```
podSpec:
  hostNetwork: true
```

### Example: Overriding `imagePullPolicy`

The setting below will add or overwrite the Deployment resource's: `.spec.template.spec.containers[0]` field with any of the specified field. This way you can alter any implemented field in OneChart.

```
container:
  imagePullPolicy: Always
```

## Deployment Strategy

OneChart allows you to configure the deployment strategy for your Kubernetes Deployment.

```
strategy: RollingUpdate
```

Valid values are:
- `RollingUpdate` (default) - Updates pods in a rolling update fashion
- `Recreate` - Terminates all existing pods before creating new ones

### Automatic Recreate Strategy

OneChart automatically sets the strategy to `Recreate` if all the following conditions are met:
- `replicas` is set to 1
- You have volumes defined
- You haven't explicitly set a strategy

This is because volumes (especially PersistentVolumeClaims) can only be mounted by a single pod at a time.

```
volumes:
  - name: data
    path: /data
    size: 10Gi
# strategy will automatically be set to Recreate when replicas is 1
```

You can override this behavior by explicitly setting the strategy:

```
replicas: 1

volumes:
  - name: data
    path: /data
    size: 10Gi

strategy: RollingUpdate
```

## Generated Resources

OneChart generates the following Kubernetes objects:

| Kind                    | API version                      | Created when                                                                                                       |
| ----------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `Deployment`            | `apps/v1`                        | Always.                                                                                                            |
| `Service`               | `v1`                             | Always. Type `ClusterIP` by default, `NodePort` with `nodePortEnabled`, `LoadBalancer` with `loadbalancerEnabled`. |
| `Ingress`               | `networking.k8s.io/v1`           | `ingress` is set, plus one per `ingresses` entry.                                                                  |
| `Secret` (basic auth)   | `v1`                             | `ingress.nginxBasicAuth` is set.                                                                                   |
| `Secret` (opaque)       | `v1`                             | Each `fileSecrets` entry.                                                                                          |
| `ConfigMap`             | `v1`                             | `vars` is set.                                                                                                     |
| `ConfigMap` (file)      | `v1`                             | Each `volumes` entry with `fileName`.                                                                              |
| `PersistentVolumeClaim` | `v1`                             | Each `volumes` entry that is not `emptyDir`, `hostPath`, `fileName`, `existingClaim` or `existingConfigMap`.       |
| `SealedSecret`          | `bitnami.com/v1alpha1`           | `sealedSecrets` is set, plus one per `sealedFileSecrets` entry.                                                    |
| `PodDisruptionBudget`   | `policy/v1`                      | `podDisruptionBudgetEnabled` is `true` and `replicas` is greater than 1.                                           |
| `ServiceMonitor`        | `monitoring.coreos.com/v1`       | `monitor.enabled` is `true`.                                                                                       |
| `PrometheusRule`        | `monitoring.coreos.com/v1`       | `prometheusRules` is set.                                                                                          |
| `Flow`                  | `logging.banzaicloud.io/v1beta1` | `logging` is set.                                                                                                  |
| Any                     | Any                              | `extraDeploy` is set.                                                                                              |

## Configuration Reference

### Image and container

| Path               | Type    | Default        | Description                                 |
| ------------------ | ------- | -------------- | ------------------------------------------- |
| `image.repository` | string  | `nginx`        | Container image repository.                 |
| `image.tag`        | string  | `latest`       | Container image tag.                        |
| `image.pullPolicy` | string  | `IfNotPresent` | Image pull policy.                          |
| `imagePullSecrets` | list    | `[]`           | Names of image-pull secrets.                |
| `containerPort`    | integer | `80`           | Port the application listens on.            |
| `command`          | string  |                | Command to run in the container.            |
| `shell`            | string  | `/bin/sh`      | Shell used to run `command`.                |
| `container`        | map     | `{}`           | Fields merged onto the generated container. |

### Deployment

| Path                         | Type    | Default | Description                                                                                            |
| ---------------------------- | ------- | ------- | ------------------------------------------------------------------------------------------------------ |
| `replicas`                   | integer | `1`     | Number of replicas (0 to 16).                                                                          |
| `strategy`                   | string  |         | `RollingUpdate` or `Recreate`. Defaults to `Recreate` when there is 1 replica and volumes are defined. |
| `podSpec`                    | map     | `{}`    | Fields merged onto the generated pod spec.                                                             |
| `podDisruptionBudgetEnabled` | boolean | `true`  | Create a `PodDisruptionBudget` when `replicas > 1`.                                                    |
| `spreadAcrossNodes`          | boolean | `false` | Add a required pod anti-affinity on `kubernetes.io/hostname`.                                          |

### Service and networking

| Path                       | Type    | Default              | Description                                                                  |
| -------------------------- | ------- | -------------------- | ---------------------------------------------------------------------------- |
| `svcPort`                  | integer | `containerPort`      | Service port when no `ports` list is set.                                    |
| `ports`                    | list    |                      | Ports to expose: `name`, `containerPort`, `svcPort`, `nodePort`, `protocol`. |
| `nodePortEnabled`          | boolean | `false`              | Set the Service type to `NodePort`.                                          |
| `nodePort`                 | integer |                      | Static node port.                                                            |
| `loadbalancerEnabled`      | boolean | `false`              | Set the Service type to `LoadBalancer`.                                      |
| `stickySessions`           | boolean | `false`              | Set `externalTrafficPolicy: Local` and a client-IP session affinity timeout. |
| `serviceAnnotations`       | map     |                      | Extra Service annotations.                                                   |
| `ingress.host`             | string  |                      | Ingress host name.                                                           |
| `ingress.ingressClassName` | string  |                      | Ingress class name.                                                          |
| `ingress.tlsEnabled`       | boolean | `false`              | Enable TLS on the ingress.                                                   |
| `ingress.secretName`       | string  | `tls-<release name>` | TLS secret name.                                                             |
| `ingress.path`             | string  | `/`                  | Single ingress path.                                                         |
| `ingress.pathType`         | string  | `Prefix`             | Path type of `ingress.path`.                                                 |
| `ingress.paths`            | list    |                      | Multiple paths: `path`, `pathType`.                                          |
| `ingress.annotations`      | map     |                      | Ingress annotations.                                                         |
| `ingress.nginxBasicAuth`   | map     |                      | `user` and `password` for Nginx basic authentication.                        |
| `ingresses`                | list    |                      | Additional Ingresses with the same fields as `ingress`.                      |

### Service catalog metadata

| Path                 | Type   | Default | Description                                                         |
| -------------------- | ------ | ------- | ------------------------------------------------------------------- |
| `serviceName`        | string |         | `v1alpha1.opensca.dev/name` annotation.                             |
| `serviceDescription` | string |         | `v1alpha1.opensca.dev/description` annotation.                      |
| `ownerName`          | string |         | `v1alpha1.opensca.dev/owner.name` annotation.                       |
| `ownerIm`            | string |         | `v1alpha1.opensca.dev/owner.im` annotation.                         |
| `documentation`      | string |         | `v1alpha1.opensca.dev/documentation` annotation.                    |
| `logs`               | string |         | `v1alpha1.opensca.dev/logs` annotation.                             |
| `metrics`            | string |         | `v1alpha1.opensca.dev/metrics` annotation.                          |
| `issues`             | string |         | `v1alpha1.opensca.dev/issues` annotation.                           |
| `traces`             | string |         | `v1alpha1.opensca.dev/traces` annotation.                           |
| `gitSha`             | string |         | `git-sha` and `v1alpha1.opensca.dev/version.sha` annotations.       |
| `gitBranch`          | string |         | `git-branch` and `v1alpha1.opensca.dev/version.branch` annotations. |
| `gitRepository`      | string |         | `git-repository` and `v1alpha1.opensca.dev/vcs.*` annotations.      |

### Configuration and secrets

| Path                  | Type    | Default | Description                                                                 |
| --------------------- | ------- | ------- | --------------------------------------------------------------------------- |
| `vars`                | map     |         | Environment variables, rendered as a `ConfigMap`.                           |
| `secretEnabled`       | boolean | `false` | Load a secret named after the release with `envFrom`.                       |
| `secretName`          | string  |         | Load a secret with a custom name with `envFrom`.                            |
| `sealedSecrets`       | map     |         | Encrypted secret values, rendered as a `SealedSecret`.                      |
| `existingSecrets`     | list    |         | Existing secrets to load with `envFrom`: `name`, `optional`.                |
| `existingConfigMaps`  | list    |         | Existing ConfigMaps to load with `envFrom`: `name`, `optional`.             |
| `fileSecrets`         | list    |         | Secrets created and mounted as files: `name`, `path`, `subPath`, `secrets`. |
| `sealedFileSecrets`   | list    |         | Sealed secrets mounted as files: `name`, `path`, `subPath`, `filesToMount`. |
| `existingFileSecrets` | list    |         | Existing secrets mounted as files: `name`, `path`, `subPath`.               |
| `volumes`             | list    |         | Volumes and their claims. See the [Volumes](#volumes) section.              |

### Pod configuration

| Path                     | Type    | Default                      | Description                                                                               |
| ------------------------ | ------- | ---------------------------- | ----------------------------------------------------------------------------------------- |
| `initContainers`         | list    | `[]`                         | Init containers: `name`, `image`, `tag`, `imagePullPolicy`, `command`, `securityContext`. |
| `sidecar`                | map     |                              | Sidecar container: `repository`, `tag`, `shell`, `command`.                               |
| `serviceAccount`         | string  |                              | Sets `spec.serviceAccountName`. No `ServiceAccount` is created.                           |
| `podSecurityContext`     | map     | `{fsGroup: 999}`             | Pod security context.                                                                     |
| `securityContext`        | map     | `{}`                         | Container security context.                                                               |
| `nodeSelector`           | map     | `{}`                         | Pod node selector.                                                                        |
| `tolerations`            | list    | `[]`                         | Pod tolerations.                                                                          |
| `affinity`               | map     | `{}`                         | Pod affinity, merged with the `spreadAcrossNodes` anti-affinity.                          |
| `podLabels`              | map     | `{}`                         | Extra pod labels.                                                                         |
| `podAnnotations`         | map     | `{}`                         | Extra pod annotations.                                                                    |
| `probe.enabled`          | boolean | `false`                      | Enable the HTTP readiness probe.                                                          |
| `probe.path`             | string  | `/`                          | Readiness probe path.                                                                     |
| `probe.settings`         | map     |                              | Readiness probe tuning, rendered verbatim.                                                |
| `livenessProbe.enabled`  | boolean | `false`                      | Enable the HTTP liveness probe.                                                           |
| `livenessProbe.path`     | string  | `/`                          | Liveness probe path.                                                                      |
| `livenessProbe.settings` | map     |                              | Liveness probe tuning, rendered verbatim.                                                 |
| `resources.requests`     | map     | `{cpu: 200m, memory: 200Mi}` | Requested resources.                                                                      |
| `resources.limits`       | map     |                              | Resource limits.                                                                          |
| `resources.ignore`       | boolean | `false`                      | Omit the `resources` block entirely.                                                      |
| `resources.ignoreLimits` | boolean | `false`                      | Render only the requests.                                                                 |

### Observability and extensions

| Path                       | Type    | Default             | Description                                                                              |
| -------------------------- | ------- | ------------------- | ---------------------------------------------------------------------------------------- |
| `monitor.enabled`          | boolean | `false`             | Create a `ServiceMonitor`.                                                               |
| `monitor.path`             | string  | `/metrics`          | Metrics scrape path.                                                                     |
| `monitor.portName`         | string  | first declared port | Port name to scrape.                                                                     |
| `monitor.scheme`           | string  | `http`              | Scrape scheme.                                                                           |
| `monitor.scrapeTimeout`    | string  |                     | Scrape timeout.                                                                          |
| `prometheusRules`          | list    |                     | `PrometheusRule` alerts: `name`, `message`, `runBookURL`, `expression`, `for`, `labels`. |
| `logging.framework`        | string  |                     | `slog_json` adds a JSON parser and a record transformer.                                 |
| `logging.filters`          | list    |                     | Logging operator filters.                                                                |
| `logging.localOutputRefs`  | list    |                     | Local output references.                                                                 |
| `logging.globalOutputRefs` | list    |                     | Global output references.                                                                |
| `extraDeploy`              | string  |                     | Arbitrary Kubernetes manifests rendered verbatim.                                        |

### Naming and labels

| Path               | Type   | Default | Description                                                       |
| ------------------ | ------ | ------- | ----------------------------------------------------------------- |
| `nameOverride`     | string | `""`    | Overrides the `app.kubernetes.io/name` label.                     |
| `fullnameOverride` | string | `""`    | Accepted for compatibility; has no effect in the current version. |
| `component`        | string | `""`    | Adds the `app.kubernetes.io/component` label.                     |
| `partOf`           | string | `""`    | Adds the `app.kubernetes.io/part-of` label.                       |
