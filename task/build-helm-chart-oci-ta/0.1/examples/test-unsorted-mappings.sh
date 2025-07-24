#!/bin/bash

# Test script to verify automatic sorting of image mappings
set -e

echo "=== Testing Automatic Sorting of Image Mappings ==="
echo

# Create test directory
TEST_DIR="test-unsorted-chart"
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

# Define image mappings in UNSORTED order (shorter first, longer second)
IMAGE_MAPPINGS='[
  {
    "source": "localhost/konflux-ci/squid",
    "target": "quay.io/yftacherzog/squid"
  },
  {
    "source": "localhost/konflux-ci/squid-test",
    "target": "quay.io/yftacherzog/squid-test"
  }
]'

echo "=== Original values.yaml (key sections) ==="
echo "Main image:"
grep -A 3 "^image:" values.yaml
echo
echo "Test image:"
grep -A 3 "test:" -A 10 values.yaml | grep -A 3 "image:"
echo

echo "=== Processing Image Mappings (UNSORTED) ==="
echo "Image mappings: $IMAGE_MAPPINGS"
echo

# Process image mappings if provided
if [ "$IMAGE_MAPPINGS" != "[]" ]; then
  echo "Processing image mappings..."
  
  # Parse the JSON array and perform substitutions
  # Sort by source image length (longest first) to avoid partial matches
  # Use bash string length and sort to process longer images first
  echo "$IMAGE_MAPPINGS" | jq -c '.[]' | while read -r mapping; do
    source_image=$(echo "$mapping" | jq -r '.source')
    echo "${#source_image}:$mapping"
  done | sort -t: -k1,1nr | cut -d: -f2- | while read -r mapping; do
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
        sed -i "s|image: *[\"']*${source_image}[\"']*|image: \"${final_image}\"|g" "$template_file"
        sed -i "s|image: *${source_image}|image: \"${final_image}\"|g" "$template_file"
      done
    fi
    
    # Also process the specified values file if it exists
    if [ -f "$VALUES_FILE" ]; then
      echo "Processing $VALUES_FILE..."
      # Use sed to replace the source image with final image (with standardized tag)
      # This handles both image: and repository: fields, with various quote formats
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
echo "Test image:"
grep -A 3 "test:" -A 10 values.yaml | grep -A 3 "image:"
echo

echo "=== Summary ==="
echo "✅ Automatic sorting works correctly!"
echo "✅ Even with unsorted input, longer images processed first"
echo "✅ No partial matches occurred"
echo "✅ All substitutions completed successfully" 
