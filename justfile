set allow-duplicate-recipes
set allow-duplicate-variables
import? 'rocks.just'

[private]
@default:
  just --list
  echo ""
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Generate the OCB manifest
[group("build")]
ocb-manifest version=latest_version manifest=(version + "/manifest.yaml"):
  #!/usr/bin/env bash
  BASE_URL="https://raw.githubusercontent.com/open-telemetry/opentelemetry-collector-releases\
  /refs/tags/v{{version}}/distributions/"
  wget "${BASE_URL}/otelcol/manifest.yaml" -O "{{version}}/manifest-core.yaml" --quiet
  wget "${BASE_URL}/otelcol-contrib/manifest.yaml" -O "{{version}}/manifest-contrib.yaml" --quiet
  yq eval-all '
    select(fileIndex == 0) as $core |
    select(fileIndex == 1) as $contrib |
    select(fileIndex == 2) as $additions |
    $contrib |
    with_entries(.value |= map(select(.gomod | contains($additions.*.[])))) as $filtered |
    $filtered *+ $core
  ' {{version}}/manifest-core.yaml {{version}}/manifest-contrib.yaml {{version}}/manifest-additions.yaml \
    | tee {{manifest}} >/dev/null
  echo "OCB manifest generated in {{manifest}}"

# Generate a rock for the latest version of the upstream project
[arg("source_repo", help="Repository of the upstream project in 'org/repo' form")]
[group("maintenance")]
update source_repo:
  #!/usr/bin/env bash
  just --justfile rocks.just update {{source_repo}}
  # Additional update steps (Grafana UI)
  latest_release="$(gh release list --repo {{source_repo}} --exclude-pre-releases --limit=1 --json tagName --jq '.[0].tagName')"
  # Explicitly filter out prefixes for known rocks, so we can notice if a new rock has a different schema
  version="${latest_release}"
  version="${version#mimir-}"  # mimir
  version="${version#cmd/builder/v}"  # opentelemetry-collector
  version="${version#v}"  # Generic v- prefix
  # Substitute the additional version reference
  cd "$version"
  # Move the Go version to `ocb` from the `opentelemetry-collector` part
  yq -i '(.parts.ocb.build-snaps) = (.parts.opentelemetry-collector.build-snaps | .[])' rockcraft.yaml
  yq -i 'del(.parts.opentelemetry-collector.build-snaps)' rockcraft.yaml
  # Move the version tag to `ocb` from the `opentelemetry-collector` part
  yq -i '(.parts.ocb.source-tag) = (.parts.opentelemetry-collector.source-tag)' rockcraft.yaml
  yq -i 'del(.parts.opentelemetry-collector.source-tag)' rockcraft.yaml
  # Generate the OCB manifest
  just ocb-manifest "$version"
