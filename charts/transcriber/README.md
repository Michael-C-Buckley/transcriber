# Transcriber Helm Chart

This chart deploys the transcriber poller as a Kubernetes `CronJob`. Each run
discovers videos from the configured YouTube sources, writes transcripts, and
exits. `concurrencyPolicy: Forbid` prevents the schedule from starting a second
Job while the previous one is still active; the application also keeps its
`poll.lock` for protection against manual or other concurrent invocations.

The chart does not create a Service, Ingress, Namespace, or ServiceAccount.

## Install

Build and publish the image with an immutable Git SHA tag, then set that tag in
your values. A ready-to-edit example is in `example-values.yaml`:

```sh
helm upgrade --install transcriber ./charts/transcriber \
  --namespace transcriber \
  --create-namespace \
  -f example-values.yaml
```

The default image repository is
`ghcr.io/michael-c-buckley/transcriber`. `image.tag` uses the chart's
`appVersion` only when left empty, so deployments should set it explicitly to
the immutable image tag they intend to run. `image.pullPolicy` defaults to
`IfNotPresent`.

## Sources

The chart creates a ConfigMap containing `/etc/transcriber/config` and, in
chart-managed mode, one URL per `sources.entries` item in `sources.txt`:

```yaml
sources:
  entries:
    - https://www.youtube.com/@ExampleChannel/videos
    - https://www.youtube.com/playlist?list=EXAMPLE
```

Instead, use an existing ConfigMap with a configurable key:

```yaml
sources:
  existingConfigMap: my-transcriber-sources
  existingConfigMapKey: sources.txt
```

The source file is always mounted at `/etc/transcriber/sources.txt` alongside
the generated application configuration. Blank lines and lines beginning with
`#` are ignored by the poller. One of `sources.entries` or
`sources.existingConfigMap` must be configured.

## Git output

Git synchronization is disabled by default. Enable it and set the remote
repository that receives transcript output:

```yaml
git:
  enabled: true
  remote: git@github.com:example/transcripts.git
  branch: main
```

When enabled, the poller initializes the output repository if needed, pulls
before each scan, commits, and pushes after processing. A diverged local branch
is reset to the remote. `git.commitMessage`, `git.authorName`, and
`git.authorEmail` configure generated commits. Supply push credentials using
mounted SSH files or a Git credential helper; keep credentials in a Kubernetes
Secret, not in `git.remote` or a values file.

## Persistence

By default the chart creates a `ReadWriteOnce` PVC named after the release,
with a size of `10Gi`. The data volume is mounted at
`/var/lib/transcriber`; the poller stores `processed.txt` and `poll.lock` in
`state/`, and transcripts under `output/`.

For Rook/Ceph or another cluster storage class, set the class without making
the chart depend on a particular provisioner:

```yaml
persistence:
  storageClass: ceph-block
  size: 10Gi
```

An existing PVC can be reused:

```yaml
persistence:
  existingClaim: transcriber-data
```

For testing only, persistence can be disabled:

```yaml
persistence:
  enabled: false
```

This uses `emptyDir`; `processed.txt` and generated output are lost when the
Pod is deleted. The chart does not set a StorageClass when
`persistence.storageClass` is empty.

## Schedule and security

The default schedule is `5 * * * *` in `America/New_York`. It can be changed
with `schedule` and `timeZone`. The defaults also retain Jobs for a short
period, limit retries, and set `startingDeadlineSeconds` to 900.

The Pod runs as UID/GID `65532`, drops all Linux capabilities, disallows
privilege escalation, uses the runtime-default seccomp profile, and has a
read-only root filesystem. The data PVC and `/tmp` `emptyDir` are writable.
`HOME` and `XDG_CACHE_HOME` point into `/tmp` for tools that need a cache.

The image is built to run as UID/GID `65532`. Keep `tmp.enabled: true` when
using the default read-only root filesystem unless an additional writable
runtime path is supplied.

Application tuning and Git settings are written to the mounted config file so
the image stays deployment-agnostic. Additional environment entries, volumes,
and mounts can be supplied through `transcriber.extraEnv`, `extraVolumes`, and
`extraVolumeMounts`. Do not put credentials in values; authentication should
use Kubernetes Secrets or mounted files.

## Manual Jobs and logs

Create an immediate Job from the CronJob:

```sh
kubectl create job --namespace transcriber \
  --from=cronjob/transcriber transcriber-manual-$(date +%s)
```

Inspect Jobs and Pods:

```sh
kubectl -n transcriber get jobs
kubectl -n transcriber get pods
```

View the newest Job's logs:

```sh
job="$(kubectl -n transcriber get jobs \
  --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{.items[-1:].metadata.name}')"
kubectl -n transcriber logs "job/$job"
```

## Flux

The chart can be referenced from a Flux `GitRepository` using a HelmRelease
whose chart path is `./charts/transcriber`, or packaged and published as an
OCI chart later. No Flux-specific resources are installed by this chart. Keep
the image tag, source configuration, and storage settings in the HelmRelease
values or a separate values file.

## Upgrade and uninstall

Upgrade with the same release name and values:

```sh
helm upgrade transcriber ./charts/transcriber \
  --namespace transcriber \
  -f example-values.yaml
```

Uninstalling removes the CronJob and chart-managed resources. PVC reclaim
behavior is controlled by the cluster's StorageClass; back up transcript data
before uninstalling if it must be retained.

## Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/michael-c-buckley/transcriber` | Container image repository |
| `image.tag` | `""` | Image tag; empty uses `appVersion`, deployments should use a Git SHA |
| `image.pullPolicy` | `IfNotPresent` | Kubernetes image pull policy |
| `schedule` | `5 * * * *` | Cron schedule |
| `timeZone` | `America/New_York` | Cron schedule timezone |
| `concurrencyPolicy` | `Forbid` | Prevent overlapping scheduled Jobs |
| `sources.entries` | `[]` | URLs for a chart-managed ConfigMap |
| `sources.existingConfigMap` | `""` | Existing source ConfigMap name |
| `transcriber.requestDelay` | `1` | Delay between extractor requests |
| `transcriber.videoDelay` | `10` | Delay between videos |
| `transcriber.scanLimit` | `20` | Videos inspected per source |
| `git.enabled` | `false` | Pull, commit, and push transcript output with Git |
| `git.remote` | `""` | Git remote URL; required when Git is enabled |
| `git.branch` | `main` | Transcript output branch |
| `git.commitMessage` | `Transcriber output` | Generated commit message |
| `git.authorName` | `Transcriber` | Generated commit author name |
| `git.authorEmail` | `transcriber@localhost` | Generated commit author email |
| `persistence.enabled` | `true` | Use persistent storage |
| `persistence.existingClaim` | `""` | Existing PVC name |
| `persistence.storageClass` | `""` | Optional StorageClass name |
| `persistence.size` | `10Gi` | Managed PVC size |
| `resources` | See `values.yaml` | Container requests and limits |
| `podSecurityContext` | See `values.yaml` | Pod UID, GID, and seccomp settings |
| `containerSecurityContext` | See `values.yaml` | Root filesystem and capability settings |
| `nodeSelector` | `{}` | Node selection constraints |
| `tolerations` | `[]` | Pod tolerations |
| `affinity` | `{}` | Pod affinity and anti-affinity |
| `extraVolumes` | `[]` | Additional Pod volumes |
| `extraVolumeMounts` | `[]` | Additional container mounts |
