set quiet # Recipes are silent by default
set export # Just variables are exported to environment variables

rock_name := `echo ${PWD##*/} | sed 's/-rock//'`
# To find the latest version, get the "last" folder that starts with a number
latest_version := `find . -maxdepth 1 -type d -name '[0-9]*' | sort -V | tail -n1 | sed 's@./@@'`

[private]
default:
  just --list

# Push an OCI image to a local registry
[private]
push-to-registry version:
  echo "Pushing $rock_name $version to local registry"
  rockcraft.skopeo --insecure-policy copy --dest-tls-verify=false \
    "oci-archive:${version}/${rock_name}_${version}_amd64.rock" \
    "docker://localhost:32000/${rock_name}-dev:${version}" >/dev/null

# Pack a rock of a specific version
pack version:
  echo "Packing opentelemetry-collector: $version"
  cd "$version" && rockcraft pack

# `rockcraft clean` for a specific version
clean version:
  echo "Cleaning opentelemetry-collector: $version"
  cd "$version" && rockcraft clean

# Run a rock and open a shell into it with `kgoss`
run version=latest_version: (push-to-registry version)
  kgoss edit -i localhost:32000/${rock_name}-dev:${version}

# Run all the tests
[group("test")]
test version=latest_version: (push-to-registry version) \
  (test-isolation version) \
  (test-integration version)

# Test the rock with `kgoss`
[group("test")]
test-isolation version=latest_version: (push-to-registry version)
  GOSS_OPTS="--retry-timeout 60s" kgoss run -i localhost:32000/${rock_name}-dev:${version}

# Test the rock integration with other workloads
[group("test")]
test-integration version=latest_version: (push-to-registry version)
  #!/usr/bin/env bash
  # For all the subfolder in tests/
  for test_folder in $(find tests -mindepth 1 -maxdepth 1 -type d | sed 's@tests/@@'); do
    # Create a namespace for the tests to run in
    namespace="test-${rock_name}-rock-${test_folder//_/-}"
    echo "+ Preparing the testing environment"
    kubectl delete all --all -n "$namespace" >/dev/null
    kubectl delete namespace "$namespace" >/dev/null
    kubectl create namespace "$namespace"
    # For each  '.yaml' file (excluding 'goss.yaml')
    for manifest in $(find tests/${test_folder} -type f -name '*.yaml' | grep -v 'goss.yaml'); do
      kubectl apply -f "$manifest" -n "$namespace"  # deploy it in the test namespace
    done
    sleep 15 # Wait for the pods to settle and otel-collector to remote-write
    NAMESPACE="$namespace" goss \
      --gossfile "tests/${test_folder}/goss.yaml" \
      --log-level debug \
      validate \
      --retry-timeout=120s \
      --sleep=5s
    # Cleanup
    echo "+ Cleaning up the testing environment"
    kubectl delete all --all -n "$namespace"
    kubectl delete namespace "$namespace"
  done
