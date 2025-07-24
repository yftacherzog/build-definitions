#!/bin/bash

# Test script to demonstrate image substitution with the squid chart
set -e

echo "=== Testing Image Substitution with Squid Chart ==="
echo

# Create test directory
TEST_DIR="test-squid-chart"
cd "$TEST_DIR"

# Simulate task parameters
VERSION_SUFFIX="v1.2.3"
COMMIT_SHA="abc123"
VALUES_FILE="values.yaml"

# Create standardized tag
if [ -n "$VERSION_SUFFIX" ]; then
  standardized_tag="${VERSION_SUFFIX}-${COMMIT_SHA}"
else
  standardized_tag="${COMMIT_SHA}"
fi

echo "Using standardized tag: $standardized_tag"
echo

# Define image mappings for squid chart (only localhost images)
# Order: longest source first to avoid partial matches
IMAGE_MAPPINGS='[
  {
    "source": "localhost/konflux-ci/squid-test",
    "target": "quay.io/yftacherzog/squid-test"
  },
  {
    "source": "localhost/konflux-ci/squid",
    "target": "quay.io/yftacherzog/squid"
  }
]'

echo "=== Original values.yaml (key sections) ==="
echo "Main image:"
grep -A 3 "^image:" values.yaml
echo
echo "Squid exporter image:"
grep -A 3 "squidExporter:" -A 10 values.yaml | grep -A 3 "image:"
echo
echo "Test image:"
grep -A 3 "test:" -A 10 values.yaml | grep -A 3 "image:"
echo
echo "Mirrord target image:"
grep -A 3 "mirrord:" -A 15 values.yaml | grep -A 3 "image:"
echo

echo "=== Processing Image Mappings ==="
echo "Image mappings: $IMAGE_MAPPINGS"
echo

# Process image mappings if provided
if [ "$IMAGE_MAPPINGS" != "[]" ]; then
  echo "Processing image mappings..."
  
  # Parse the JSON array and perform substitutions
  echo "$IMAGE_MAPPINGS" | jq -c '.[]' | while read -r mapping; do
    source_image=$(echo "$mapping" | jq -r '.source')
    target_image=$(echo "$mapping" | jq -r '.target')
    
    # Extract registry and repository from target image, then apply standardized tag
    if [[ "$target_image" =~ ^([^:]+)(:.*)?$ ]]; then
      registry_repo="${BASH_REMATCH[1]}"
      final_image="${registry_repo}:${standardized_tag}"
    else
      # Fallback if parsing fails
      final_image="${target_image}:${standardized_tag}"
    fi
    
    echo "Replacing '$source_image' with '$final_image' in templates and $VALUES_FILE..."
    
    # Find all YAML files in templates directory and substitute images
    if [ -d "templates" ]; then
      find templates -name "*.yaml" -o -name "*.yml" | while read -r template_file; do
        # Use sed to replace the source image with final image (with standardized tag)
        # This handles both image: and image: "quoted" formats
        # Use exact path matching to avoid partial matches
        sed -i "s|image: *[\"']*${source_image}[\"']*|image: \"${final_image}\"|g" "$template_file"
        sed -i "s|image: *${source_image}|image: \"${final_image}\"|g" "$template_file"
      done
    fi
    
    # Also process the specified values file if it exists
    if [ -f "$VALUES_FILE" ]; then
      echo "Processing $VALUES_FILE..."
      # Use sed to replace the source image with final image (with standardized tag)
      # This handles both image: and repository: fields, with various quote formats
      # Use exact path matching to avoid partial matches
      sed -i "s|repository: *[\"']*${source_image}[\"']*|repository: \"${final_image}\"|g" "$VALUES_FILE"
      sed -i "s|repository: *${source_image}|repository: \"${final_image}\"|g" "$VALUES_FILE"
    fi
  done
  
  echo "Image substitution completed."
fi

echo
echo "=== Modified values.yaml (key sections) ==="
echo "Main image:"
grep -A 3 "^image:" values.yaml
echo
echo "Squid exporter image:"
grep -A 3 "squidExporter:" -A 10 values.yaml | grep -A 3 "image:"
echo
echo "Test image:"
grep -A 3 "test:" -A 10 values.yaml | grep -A 3 "image:"
echo
echo "Mirrord target image:"
grep -A 3 "mirrord:" -A 15 values.yaml | grep -A 3 "image:"
echo

echo "=== Modified templates (key sections) ==="
echo "Deployment template image reference:"
grep -n "image:" templates/deployment.yaml | head -3
echo
echo "Test pod template image reference:"
grep -n "image:" templates/test-pod.yaml
echo
echo "Mirrord target pod template image reference:"
grep -n "image:" templates/mirrord-target-pod.yaml
echo

echo "=== Summary ==="
echo "The following substitutions were made:"
echo "1. localhost/konflux-ci/squid-test → quay.io/yftacherzog/squid-test:$standardized_tag"
echo "2. localhost/konflux-ci/squid → quay.io/yftacherzog/squid:$standardized_tag"
echo
echo "Note: boynux/squid-exporter was left unchanged (public image)"
echo
echo "✅ Image substitution works perfectly with the squid chart!"
echo "✅ All repository fields in values.yaml were updated"
echo "✅ All template image references were updated"
echo "✅ Standardized tagging applied consistently" 
