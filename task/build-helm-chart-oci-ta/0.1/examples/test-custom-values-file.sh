#!/bin/bash

# Test script to demonstrate custom values file functionality
# This simulates the image substitution part of the build-helm-chart task

set -e

# Test configuration
IMAGE_MAPPINGS='[
  {
    "source": "localhost/myapp",
    "target": "quay.io/myorg/myapp"
  },
  {
    "source": "localhost/sidecar",
    "target": "quay.io/myorg/sidecar"
  }
]'

# Simulate task parameters
VERSION_SUFFIX="v1.2.3"
COMMIT_SHA="abc123"
VALUES_FILE="values-prod.yaml"

# Create test directory structure
mkdir -p test-chart/templates
cp test-chart-templates/deployment.yaml test-chart/templates/
cp test-chart-templates/values.yaml test-chart/values-prod.yaml

echo "=== Original Chart Template ==="
cat test-chart/templates/deployment.yaml

echo -e "\n=== Original ${VALUES_FILE} ==="
cat test-chart/${VALUES_FILE}

echo -e "\n=== Processing Image Mappings ==="
echo "Image mappings: $IMAGE_MAPPINGS"
echo "Values file: $VALUES_FILE"

# Process image mappings (simulating the task logic)
if [ "$IMAGE_MAPPINGS" != "[]" ]; then
    echo "Processing image mappings..."
    
    # Create the standardized tag format
    if [ -n "$VERSION_SUFFIX" ]; then
        standardized_tag="${VERSION_SUFFIX}-${COMMIT_SHA}"
    else
        standardized_tag="${COMMIT_SHA}"
    fi
    
    echo "Using standardized tag: $standardized_tag"
    
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
        
        echo "Replacing '$source_image' with '$final_image' in templates and ${VALUES_FILE}..."
        
        # Find all YAML files in templates directory and substitute images
        if [ -d "test-chart/templates" ]; then
            find test-chart/templates -name "*.yaml" -o -name "*.yml" | while read -r template_file; do
                # Use sed to replace the source image with final image (with standardized tag)
                # This handles both image: and image: "quoted" formats
                sed -i "s|image: *[\"']*${source_image}[\"']*|image: \"${final_image}\"|g" "$template_file"
                sed -i "s|image: *${source_image}|image: \"${final_image}\"|g" "$template_file"
            done
        fi
        
        # Also process the specified values file if it exists
        if [ -f "test-chart/${VALUES_FILE}" ]; then
            echo "Processing ${VALUES_FILE}..."
            # Use sed to replace the source image with final image (with standardized tag)
            # This handles both image: and repository: fields, with various quote formats
            sed -i "s|image: *[\"']*${source_image}[\"']*|image: \"${final_image}\"|g" "test-chart/${VALUES_FILE}"
            sed -i "s|image: *${source_image}|image: \"${final_image}\"|g" "test-chart/${VALUES_FILE}"
            sed -i "s|repository: *[\"']*${source_image}[\"']*|repository: \"${final_image}\"|g" "test-chart/${VALUES_FILE}"
            sed -i "s|repository: *${source_image}|repository: \"${final_image}\"|g" "test-chart/${VALUES_FILE}"
        fi
    done
    
    echo "Image substitution completed."
fi

echo -e "\n=== Modified Chart Template ==="
cat test-chart/templates/deployment.yaml

echo -e "\n=== Modified ${VALUES_FILE} ==="
cat test-chart/${VALUES_FILE}

echo -e "\n=== Summary ==="
echo "The following substitutions were made:"
echo "1. localhost/myapp → quay.io/myorg/myapp:${standardized_tag}"
echo "2. localhost/sidecar → quay.io/myorg/sidecar:${standardized_tag}"
echo "Values file processed: ${VALUES_FILE}"

# Cleanup
rm -rf test-chart 
