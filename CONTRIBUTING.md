# Contributing to docker-php

We welcome bug reports, discussions, fixes, and feature proposals. Contributions
are managed through GitHub issues and pull requests.

## Pull requests

1. Choose the target branch for the change:
   - For a PHP image or release-specific change, use the matching `release/*`
     branch.
   - For repository-wide documentation or workflow changes, use `main`.
2. Fork the repository and create a topic branch from the target branch.
3. Make the change and add or update tests and documentation where relevant.
4. Run the checks that apply to the change; see [Checks](#checks).
5. Open a pull request against the same branch you used as the base. Describe
   the change, its impact, and the checks you ran. Include relevant issue links
   and call out any checks you could not run.

Use clear commit messages. A concise summary is enough for a small change; for
a larger change, include a short explanation of its impact.

## Checks

For Dockerfile changes, run [Hadolint](https://github.com/hadolint/hadolint):

```shell
hadolint Dockerfile
```

Release branches have a CI workflow that builds and checks amd64 and arm64
images, runs smoke checks and tests, and scans the image. Consult the workflow
on the target release branch for the current commands and setup. In particular,
the test script may expect the image name and environment prepared by CI; do not
assume it can run by itself in a fresh checkout.

For documentation or workflow changes targeting `main`, review the affected
workflow or links directly and explain that review in the pull request.

## Reporting bugs

Report public bugs using [GitHub Issues](https://github.com/Endava/docker-php/issues/new).
Include:

- A short summary and the affected PHP version, image variant, and image tag.
- Steps to reproduce, with a minimal example when possible.
- What you expected and what happened instead.
- Relevant logs and troubleshooting details, with secrets and sensitive values
  removed.
- Whether the issue also occurs with the latest published image for that line.

## Alpine PECL packages

Some Alpine release branches use fitness functions to check whether PECL-related
packages are available from the configured repositories. Before adding or
changing a manually built extension, inspect the fitness workflow and Dockerfile
on the target release branch; package names and Alpine versions differ between
branches. Current examples of package availability checks are in the
[ZTS fitness workflows](.github/workflows/fitness-functions-release-8.4-zts.yml).

If a package is unavailable and a manual build is needed, follow the pattern
already used by that release branch. When the package becomes available, update
the Dockerfile to use the repository package and adjust or remove the
unavailability check as appropriate. Do not copy a version-specific recipe
without verifying it against the target branch.

## Project policies

- Contributions are licensed under the [Apache 2.0 License](LICENSE). Contact
  [opensource@endava.com](mailto:opensource@endava.com) if you have concerns.
- Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).
