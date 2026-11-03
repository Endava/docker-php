# Maintainer Guide

This guide describes the recurring work involved in maintaining the Endava PHP
container images. Treat the workflows and release branches as the source of
truth; update this guide when their behavior changes.

## Repository and release model

- `main` holds repository-wide documentation and automation, including the
  release security scan, fitness functions, and README maintenance workflows.
- Each `release/X.Y` branch is maintained independently. PHP version, base
  distribution, extensions, and image build behavior are defined on that
  branch; changes on `main` do not automatically update release branches.
- Suffix branches such as `release/X.Y-ubuntu` and `release/X.Y-zts` are
  separate image lines. Check the [Supported Versions](README.md#supported-versions),
  [Experimental Versions](README.md#experimental-versions), and
  [Unsupported Versions](README.md#unsupported-versions) tables for current
  project status. ZTS is identified as experimental in the README.
- Published image tags and supported PHP versions change over time. Check the
  [PHP supported versions and end-of-life list](https://www.php.net/supported-versions.php)
  before deciding whether a line still receives updates.

## Recurring maintainer checklist

### Regular review

- Review new [issues](https://github.com/Endava/docker-php/issues) and pull
  requests. Reproduce reported problems when possible, confirm the target branch,
  and check that the change includes relevant tests or documentation.
- Review the GitHub Actions runs for failed release builds, fitness functions,
  and security scans. Inspect the failing job and logs before deciding whether
  a failure is a code regression, an upstream package change, or an external
  service or scanner problem.
- Review published image availability and security reports for supported and
  experimental lines. The README links to the latest published release
  artifacts; do not treat a green build alone as proof that a release and its
  assets are available.

### When updating a release branch

1. Create a topic branch in your fork from the matching canonical `release/*`
   branch. See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution and pull
   request guidance.
2. For a PHP point update, check that version against the package source used by
   that branch. Alpine branches use their configured Alpine repositories;
   Ubuntu branches use their configured PHP package source. ZTS branches may
   also depend on PHP package and integration changes. Do not copy a version
   from another release line without checking compatibility.
3. Review all related build inputs: the Dockerfile, helper scripts, tests, and
   the branch's `.github/workflows/ci.yml`. Update fitness-function expectations
   on `main` when the expected upstream distribution or package state changes.
4. Review the pull request checks for both amd64 and arm64 builds, Dockerfile
   lint, smoke checks, tests, and scanning. Resolve failures or document a
   verified external cause before merging.
5. After the release branch is ready, publish using the project's established
   release process. The branch CI publishes images on pushes to canonical
   `release/**` branches. A semantic version tag (`X.Y.Z`) triggers release
   note generation and a GitHub release in the branch's `release-notes.yml`.
   Follow existing repository permissions and review practices when merging or
   tagging.
6. Verify the resulting image tags in the supported registries and confirm the
   GitHub release has its expected assets. The main-branch security workflow
   attaches vulnerability and size reports to releases. The README automation
   then proposes updates to the latest-release links once the reports exist.

## Automation and what to monitor

| Workflow | Maintainer responsibility |
| --- | --- |
| [Release CI](https://github.com/Endava/docker-php/blob/release/8.5/.github/workflows/ci.yml) (`.github/workflows/ci.yml` on each release branch) | Builds and checks amd64 and arm64 images on release-branch pushes and pull requests. Publishing is restricted to the canonical Endava repository and release branches. |
| [Release notes](https://github.com/Endava/docker-php/blob/release/8.5/.github/workflows/release-notes.yml) (`release-notes.yml` on each release branch) | A `X.Y.Z` tag generates release notes and a GitHub release. Confirm the image exists before tagging. |
| [Security Scan](.github/workflows/security-scan.yml) | Runs on pushes to `main`, manually, and daily at 10:15 UTC. It scans the configured release-branch matrix and uploads reports and size assets to GitHub releases. Vulnerability findings are reported; the Trivy table step is configured not to fail solely because findings exist. Review the report and status rather than interpreting a successful scan as vulnerability-free. |
| [PHP fitness functions](.github/workflows/) | The per-version workflows run on pushes to `main` and daily at 10:15 UTC. They check assumptions about upstream Alpine/Ubuntu versions, package availability, and selected dependencies. Update the relevant expectation when upstream changes are intentional. |
| [README Latest Releases](.github/workflows/readme-latest-releases.yml) | Runs after Security Scan completion or manually. It opens a pull request to update README release links from published releases that have vulnerability and size assets. Review the generated changes before merging. |
| [Docker Hub Description](.github/workflows/dockerhub-description.yml) | Updates the Docker Hub overview when `README.md` changes on `main`, or when manually dispatched. Check the run if the Docker Hub description is stale. |

The security scan's release matrix is explicitly listed in its workflow. When a
release line is added, retired, or renamed, check that matrix and the README
version tables together. Fitness-function filenames and coverage also vary by
version and variant; inspect the workflow files rather than assuming every line
has an identical check.

## Troubleshooting and references

- **Build failure:** Identify the failing architecture and step first. Check
  package repository availability, Dockerfile lint, build logs, smoke checks,
  and test output. Compare only with the matching release branch.
- **Trivy database download failure:** Check the scanner's database download
  logs and configured database source before treating the failure as an image
  vulnerability. Trivy database rate limits or fetch errors can prevent a scan
  from starting.
- **Fitness function failure:** Check whether the upstream distribution,
  package, or dependency actually changed. Update the pinned build input and
  its expected assertion together when a change is intended.
- **Missing release report or stale README link:** Confirm the security scan
  completed for the release line, the GitHub release accepted the expected
  assets, and the README automation opened a pull request. The helper script is
  [update-readme-releases.php](.github/scripts/update-readme-releases.php).
- **Contribution details:** Follow [CONTRIBUTING.md](CONTRIBUTING.md), including
  its Hadolint guidance and guidance for Alpine PECL package availability and
  manual builds.
- **PHP support lifecycle:** Check the current
  [PHP supported versions](https://www.php.net/supported-versions.php) and
  [PHP end-of-life list](https://www.php.net/eol.php); do not rely on a version
  table copied into this guide.
