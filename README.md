# opentelemetry-collector-rock

[![Open a PR to OCI Factory](https://github.com/canonical/opentelemetry-collector-rock/actions/workflows/rock-release-oci-factory.yaml/badge.svg)](https://github.com/canonical/opentelemetry-collector-rock/actions/workflows/rock-release-oci-factory.yaml)
[![Publish to GHCR:dev](https://github.com/canonical/opentelemetry-collector-rock/actions/workflows/rock-release-dev.yaml/badge.svg)](https://github.com/canonical/opentelemetry-collector-rock/actions/workflows/rock-release-dev.yaml)
[![Update rock](https://github.com/canonical/opentelemetry-collector-rock/actions/workflows/rock-update.yaml/badge.svg)](https://github.com/canonical/opentelemetry-collector-rock/actions/workflows/rock-update.yaml)

[Rocks](https://canonical-rockcraft.readthedocs-hosted.com/en/latest/) for [Opentelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector-releases).
This repository holds all the necessary files to build rocks for the upstream versions we support.

The rocks on this repository are built with [OCI Factory](https://github.com/canonical/oci-factory/), which also takes care of periodically rebuilding the images.

**How do I interact with this repo?** This repo uses [`just`](https://github.com/casey/just) to easily run some commands:
```
$ just
Available recipes:
    clean version               # `rockcraft clean` for a specific version
    pack version                # Pack a rock of a specific version
    run version=latest_version  # Run a rock and open a shell into it with `kgoss`
    test version=latest_version # Test the rock with `kgoss`
```

**What are all those manifests?** Each rock version has a set of `manifest*` files, that tell OCB what to include in the Collector. We include everything in `-core`, but cherry-pick from `-contrib` what we mention in `-additions`. Running `just ocb-manifest` generates a final `manifest.yaml`, which is the one used in the rock. Summarizing:
- `manifest-core.yaml`, `manifest-contrib.yaml`: obtained via `wget` from upstream by the update-rock CI;
- `manifest-additions.yaml`: the extensions from `-contrib` that we want to include;
- `manifest.yaml`: generated by running `just ocb-manifest`, merges `manifest-core.yaml` with the items we cherry-picked from `-contrib`.

Automation takes care of:
* validating PRs, by simply trying to build the rock;
* pulling upstream releases, creating a PR with the necessary files to be manually reviewed;
* on PRs, validate the added (or modified) rocks by running `kgoss`;
* releasing to GHCR at [ghcr.io/canonical/opentelemetry-collector:dev](https://ghcr.io/canonical/opentelemetry-collector:dev), when merging to main, for development purposes.

Prerequisites:
* install [goss](https://github.com/goss-org/goss/#manual-installation) and [kgoss](https://github.com/goss-org/goss/tree/master/extras/kgoss#install)
* do not use microk8s.kubectl (from snap) due to permission errors
    * use the kubectl snap instead
* sign the [CLA](https://ubuntu.com/legal/contributors)
