# build-helm-chart-oci-ta task

The task packages and pushes a Helm chart to an OCI repository.
As Helm charts require to have a semver-compatible version to be packaged, the
task relies on git tags in order to determine the chart version during runtime.

The task computes the version based on the git commit SHA distance from the latest
tag prefixed with the value of TAG_PREFIX. The value of that tag will be used as
the version's X.Y values, and the Z value will be computed by the commit's distance
from the tag, followed by an abbreviated SHA as build metadata.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|CA_TRUST_CONFIG_MAP_KEY|The name of the key in the ConfigMap that contains the CA bundle data.|ca-bundle.crt|false|
|CA_TRUST_CONFIG_MAP_NAME|The name of the ConfigMap to read CA bundle data from.|trusted-ca|false|
|CHART_CONTEXT|Path relative to SOURCE_CODE_DIR where the chart is located|dist/chart/|false|
|COMMIT_SHA|Git commit sha to build chart for||true|
|IMAGE_MAPPINGS|JSON array of image mappings to substitute in chart templates. Format: [{"source": "localhost/my/repo", "target": "quay.io/myorg/myapp"}] Source images will be replaced with target images in all YAML files in templates/. The task automatically appends the tag format: VERSION_SUFFIX-COMMIT_SHA (or just COMMIT_SHA if VERSION_SUFFIX is empty).|[]|false|
|IMAGE|Full image reference with tag (e.g., quay.io/redhat-user-workloads/konflux-vanguard-tenant/caching/squid:on-pr-{{revision}})||true|
|SOURCE_ARTIFACT|The Trusted Artifact URI pointing to the artifact with the application source code.||true|
|SOURCE_CODE_DIR|Path relative to the workingDir where the code was pulled into|source|false|
|TAG_PREFIX|An identifying prefix on which the version tag is to be matched|helm-|false|
|VALUES_FILE|Name of the values file to process for image substitution (e.g., values.yaml, values-prod.yaml)|values.yaml|false|
|VERSION_SUFFIX|A suffix to be added to the version string|""|false|

## Results
|name|description|
|---|---|
|IMAGE_DIGEST|Digest of the OCI-Artifact just built|
|IMAGE_URL|OCI-Artifact repository and tag where the built OCI-Artifact was pushed|

