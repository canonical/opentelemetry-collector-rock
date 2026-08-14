set allow-duplicate-recipes
set allow-duplicate-variables
import? 'rocks.just'

source_repo := 'open-telemetry/opentelemetry-collector'

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

# Patch all existing major.minor folders to the newest upstream patch, refresh OCB parts and manifest
[group("maintenance")]
update:
  #!/usr/bin/env bash
  set -e
  [[ -z "{{source_repo}}" ]] && { echo "× Set 'source_repo' in the local justfile"; exit 1; }
  for folder in $(find . -maxdepth 1 -type d -regextype posix-extended -regex '\./[0-9]+\.[0-9]+' -printf '%f\n' | sort -V); do
    read -r version tag < <(just resolve-tag "$folder")
    if [[ -z "$version" ]]; then echo "→ no upstream patch found for $folder, skipping"; continue; fi
    current="$(yq -r '.version' "$folder/rockcraft.yaml")"
    if [[ "$current" == "$version" ]]; then echo "→ $folder already at $version"; continue; fi
    echo "Updating $folder: $current → $version (source-tag $tag)"
    version="$version" tag="$tag" yq -i \
      '.version = strenv(version) | .parts.ocb["source-tag"] = strenv(tag)' \
      "$folder/rockcraft.yaml"
    # Refresh the Go build-snap on the ocb part from the upstream go.mod
    TMP_DIR="$(mktemp -d)"
    gh repo clone "{{source_repo}}" "$TMP_DIR/src" -- --branch "$tag" --depth 1 2>/dev/null || true
    if [[ -f "$TMP_DIR/src/go.mod" ]]; then
      go_snap_version="$(grep -Po '^go \K(\S+)' "$TMP_DIR/src/go.mod" | sed -E 's/([0-9]+\.[0-9]+).*/\1/')"
      go_snap_version="$go_snap_version" yq -i \
        '(.parts.ocb.build-snaps[] | select(test("^go/"))) = "go/"+strenv(go_snap_version)+"/stable"' \
        "$folder/rockcraft.yaml"
    fi
    rm -rf "$TMP_DIR"
    # Regenerate the OCB manifest for this line
    just ocb-manifest "$folder"
  done
