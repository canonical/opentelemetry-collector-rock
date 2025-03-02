#!/bin/bash

# This script takes the "additions.yaml" file and the (upstream)
# otelcol-contrib/manifest.yaml as input to create a versioned
# manifest. This ensures that the contrib modules we use are
# always up-to-date with upstream.

SOURCE_MANIFEST="$1"
ADDITIONS_FILE="$2"
ADDITIONS_MANIFEST="$3"
TEMP_FILE="bare.yaml.tmp"

# Copy the original file to a temp file
cp "$ADDITIONS_FILE" "$TEMP_FILE"

# Function to extract version from module
get_version() {
    local module="$1"
    grep "$module" "$SOURCE_MANIFEST" | awk '{print $NF}'  # Extract last field (version)
}

# Process each module
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ (github\.com/[^ ]+) ]]; then
        MODULE="${BASH_REMATCH[1]}"  # Extract module path
        VERSION=$(get_version "$MODULE")
        if [[ -n "$VERSION" ]]; then
            echo "Updating $MODULE to version $VERSION"
            sed -i "s|-\s*$MODULE|- gomod: $MODULE $VERSION|" "$TEMP_FILE"
        fi
    fi
done < "$ADDITIONS_FILE"

# Create a new file with the updated versions
mv "$TEMP_FILE" "$ADDITIONS_MANIFEST"

echo "Updated $ADDITIONS_FILE with $SOURCE_MANIFEST as $ADDITIONS_MANIFEST"
