# Image Substitution Guide for Build Helm Chart OCI-TA Task

## Overview

The enhanced `build-helm-chart-oci-ta` task now supports **image substitution** - the ability to replace placeholder images in Helm chart templates with actual built images before packaging. This feature is particularly useful in CI/CD pipelines where you want to:

1. Keep placeholder images in your chart templates (e.g., `localhost/myapp`)
2. Build actual images in your pipeline
3. Replace the placeholders with the built images before packaging the chart

## Why Image Substitution?

### Problem
Traditional Helm charts often contain hardcoded image references:
```yaml
# templates/deployment.yaml
containers:
- name: app
  image: quay.io/myorg/myapp:latest  # Hardcoded!
```

This creates several issues:
- **Version coupling**: Chart version and image version are tightly coupled
- **Environment inflexibility**: Same chart can't be used across different environments
- **Build complexity**: Need to modify chart templates during build process

### Solution
Use placeholder images in templates and substitute them during build:
```yaml
# templates/deployment.yaml
containers:
- name: app
  image: localhost/myapp  # Placeholder
```

Then use the `IMAGE_MAPPINGS` parameter to replace them (note: this task uses `SOURCE_ARTIFACT` instead of a workspace):
```json
[
  {
    "source": "localhost/myapp",
    "target": "quay.io/myorg/myapp"
  }
]
```

## How It Works

### 1. Chart Template Structure
Your Helm chart templates should use placeholder images:
```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: app
        image: localhost/myapp
      - name: sidecar
        image: localhost/sidecar
```

### 2. Image Mappings Configuration
Define the substitution mappings as JSON. **The task automatically sorts mappings by source image length (longest first) to prevent partial matches**, so you can provide them in any order:
```json
[
  {
    "source": "localhost/myapp",
    "target": "quay.io/myorg/myapp"
  },
  {
    "source": "localhost/sidecar", 
    "target": "quay.io/myorg/sidecar"
  }
]
```

### 3. Task Execution
The task will:
1. Parse the JSON mappings
2. Create standardized tag format: `VERSION_SUFFIX-COMMIT_SHA` (or just `COMMIT_SHA` if `VERSION_SUFFIX` is empty)
3. Find all YAML files in `templates/` directory and the specified values file
4. Replace source images with target images (appending the standardized tag)
5. Package the modified chart
6. Push to OCI registry

### 4. Result
The packaged chart will contain the actual images with standardized tags (assuming VERSION_SUFFIX="v1.2.3" and COMMIT_SHA="abc123"):
```yaml
containers:
- name: app
  image: "quay.io/myorg/myapp:v1.2.3-abc123"
- name: sidecar
  image: "quay.io/myorg/sidecar:v1.2.3-abc123"
```

## Usage Patterns

### Pattern 1: Simple Single Image
```yaml
apiVersion: tekton.dev/v1beta1
kind: TaskRun
metadata:
  name: build-simple-chart
spec:
  taskRef:
    name: build-helm-chart-oci-ta
  params:
  - name: IMAGE
    value: "quay.io/myorg/mychart:latest"
  - name: COMMIT_SHA
    value: "abc123"
  - name: SOURCE_ARTIFACT
    value: "oci://quay.io/myorg/source:latest"
  - name: IMAGE_MAPPINGS
    value: |
      [
        {
          "source": "localhost/myapp",
          "target": "quay.io/myorg/myapp"
        }
      ]
```

### Pattern 2: Multiple Images with Different Tags
```yaml
- name: IMAGE_MAPPINGS
  value: |
    [
      {
        "source": "localhost/app",
        "target": "quay.io/myorg/app"
      },
      {
        "source": "localhost/sidecar",
        "target": "quay.io/myorg/sidecar"
      },
      {
        "source": "localhost/init",
        "target": "quay.io/myorg/init"
      }
    ]
```

### Pattern 3: TaskRun with Hardcoded Images
```yaml
apiVersion: tekton.dev/v1beta1
kind: TaskRun
metadata:
  name: build-helm-chart-with-images
spec:
  taskRef:
    name: build-helm-chart-oci-ta
  params:
  - name: IMAGE
    value: "quay.io/myorg/mychart:latest"
  - name: COMMIT_SHA
    value: "abc123"
  - name: SOURCE_ARTIFACT
    value: "oci://quay.io/myorg/source:latest"
  - name: IMAGE_MAPPINGS
    value: |
      [
        {
          "source": "localhost/myapp",
          "target": "quay.io/myorg/myapp"
        },
        {
          "source": "localhost/sidecar",
          "target": "quay.io/myorg/sidecar"
        }
      ]
```

## Best Practices

### 1. Naming Conventions
Use consistent placeholder naming:
```yaml
# Good
image: localhost/myapp
image: localhost/sidecar
image: localhost/init

# Avoid
image: placeholder/app
image: temp/sidecar
image: dummy/init
```

### 2. Version Management
- Use semantic versioning for target images
- Consider using git SHA or build number for unique identification
- Keep placeholder names simple and descriptive

### 3. Template Organization
- Keep all image references in the `templates/` directory and values files
- Use consistent indentation and formatting
- Document placeholder images in chart README

### 4. Error Handling
- Validate JSON format before passing to task
- Test image substitution with sample templates
- Monitor task logs for substitution errors

## Advanced Features

### 1. Environment-Specific Configurations
Create separate TaskRuns for different environments with hardcoded image mappings:

**Development TaskRun:**
```yaml
- name: IMAGE_MAPPINGS
  value: |
    [
      {
        "source": "localhost/myapp",
        "target": "quay.io/dev/myapp:latest"
      }
    ]
```

**Production TaskRun:**
```yaml
- name: IMAGE_MAPPINGS
  value: |
    [
      {
        "source": "localhost/myapp",
        "target": "quay.io/prod/myapp:stable"
      }
    ]
```

### 2. Multi-Environment Support
Different environments can use different image mappings:
```yaml
# Development
- name: IMAGE_MAPPINGS
  value: |
    [
      {
        "source": "localhost/myapp",
        "target": "quay.io/dev/myapp:latest"
      }
    ]

# Production  
- name: IMAGE_MAPPINGS
  value: |
    [
      {
        "source": "localhost/myapp",
        "target": "quay.io/prod/myapp:v1.2.3"
      }
    ]
```

### 3. Multiple Environment Configurations
You can create different TaskRuns for different environments:

**Development Environment:**
```yaml
- name: VALUES_FILE
  value: "values-dev.yaml"
- name: IMAGE_MAPPINGS
  value: |
    [
      {
        "source": "localhost/myapp",
        "target": "quay.io/dev/myapp"
      },
      {
        "source": "localhost/sidecar",
        "target": "quay.io/dev/sidecar"
      }
    ]
```

**Production Environment:**
```yaml
- name: VALUES_FILE
  value: "values-prod.yaml"
- name: IMAGE_MAPPINGS
  value: |
    [
      {
        "source": "localhost/myapp",
        "target": "quay.io/prod/myapp"
      },
      {
        "source": "localhost/sidecar",
        "target": "quay.io/prod/sidecar"
      }
    ]
```

## Troubleshooting

### Common Issues

1. **JSON Format Errors**
   ```bash
   # Validate JSON before using
   echo "$IMAGE_MAPPINGS" | jq .
   ```

2. **Image Not Found**
   - Check that source image names match exactly
   - Verify templates are in the correct directory
   - Ensure YAML formatting is correct

3. **Substitution Not Working**
   - Check task logs for substitution messages
   - Verify image mappings are not empty
   - Test with simple examples first

### Debugging Tips

1. **Enable Verbose Logging**
   The task outputs detailed substitution information:
   ```
   Processing image mappings...
   Replacing 'localhost/myapp' with 'quay.io/myorg/myapp:v1.2.3' in templates...
   Image substitution completed.
   ```

2. **Test Locally**
   Use the provided test script:
   ```bash
   ./examples/test-image-substitution.sh
   ```

3. **Validate Results**
   Check the packaged chart contents:
   ```bash
   tar -tzf mychart-1.2.3.tgz | grep -A 10 -B 10 "image:"
   ```

## Migration Guide

### From Hardcoded Images
1. Replace hardcoded images with placeholders
2. Update your CI/CD pipeline to pass image mappings
3. Test the substitution process
4. Deploy and verify functionality

### Example Migration
**Before:**
```yaml
# templates/deployment.yaml
containers:
- name: app
  image: quay.io/myorg/myapp:latest
```

**After:**
```yaml
# templates/deployment.yaml  
containers:
- name: app
  image: localhost/myapp
```

**TaskRun Configuration:**
```yaml
apiVersion: tekton.dev/v1beta1
kind: TaskRun
metadata:
  name: build-helm-chart
spec:
  taskRef:
    name: build-helm-chart-oci-ta
  params:
  - name: IMAGE
    value: "quay.io/myorg/mychart:latest"
  - name: COMMIT_SHA
    value: "abc123"
  - name: SOURCE_ARTIFACT
    value: "oci://quay.io/myorg/source:latest"
  - name: IMAGE_MAPPINGS
    value: |
      [
        {
          "source": "localhost/myapp",
          "target": "quay.io/myorg/myapp"
        }
      ]
```

## Conclusion

Image substitution in the `build-helm-chart-oci-ta` task provides a simple, maintainable way to handle image references in Helm charts. By using placeholder images and hardcoded substitution mappings, you can:

- Decouple chart versioning from image versioning
- Support multiple environments with separate TaskRuns
- Keep configuration simple and explicit
- Maintain clean, readable chart templates

The JSON-based configuration with hardcoded values makes it easy to understand and modify image mappings, while the robust substitution logic handles various YAML formats and edge cases. This approach is particularly well-suited for PipelineRuns with embedded specs where the number of images may vary between implementations. 
