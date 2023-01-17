# draft-docker-php

The PoC for https://github.com/exozet/docker-php-fpm/wiki/Draft-for-new-Structure

This is a docker php image is based on an alpine distribution including some tools and php extensions. You can find more details at the respective release pages on github.

# Supported Versions

| Version | Branch | Latest Release | Status | Security Report |
| --- | --- | --- | --- | --- |
| **8.2** | [release/8.2](https://github.com/exozet/draft-docker-php/tree/release/8.2) | [8.2.1](https://github.com/exozet/draft-docker-php/releases/tag/8.2.1) | [![Build Status][github_actions_82_badge]][github_actions_82_link] | [Security Report][security_report_82_link]
| **8.1** | [release/8.1](https://github.com/exozet/draft-docker-php/tree/release/8.1) | [8.1.14](https://github.com/exozet/draft-docker-php/releases/tag/8.1.14) | [![Build Status][github_actions_81_badge]][github_actions_81_link] | [Security Report][security_report_81_link]
| **8.0** | [release/8.0](https://github.com/exozet/draft-docker-php/tree/release/8.0) | [8.0.27](https://github.com/exozet/draft-docker-php/releases/tag/8.0.27) | [![Build Status][github_actions_80_badge]][github_actions_80_link] | [Security Report][security_report_80_link]

[github_actions_82_badge]: https://github.com/exozet/draft-docker-php/workflows/CI/badge.svg?branch=release/8.2
[github_actions_82_link]: https://github.com/exozet/draft-docker-php/actions?query=branch%3Arelease%2F8.2
[security_report_82_link]: https://github.com/exozet/draft-docker-php/security/code-scanning?query=is%3Aopen+branch%3Arelease%2F8.2

[github_actions_81_badge]: https://github.com/exozet/draft-docker-php/workflows/CI/badge.svg?branch=release/8.1
[github_actions_81_link]: https://github.com/exozet/draft-docker-php/actions?query=branch%3Arelease%2F8.1
[security_report_81_link]: https://github.com/exozet/draft-docker-php/security/code-scanning?query=is%3Aopen+branch%3Arelease%2F8.1

[github_actions_80_badge]: https://github.com/exozet/draft-docker-php/workflows/CI/badge.svg?branch=release/8.0
[github_actions_80_link]: https://github.com/exozet/draft-docker-php/actions?query=branch%3Arelease%2F8.0
[security_report_80_link]: https://github.com/exozet/draft-docker-php/security/code-scanning?query=is%3Aopen+branch%3Arelease%2F8.0

# Overview

At https://github.com/exozet/docker-php-fpm/wiki/Draft-for-new-Structure we collected ideas on how a new (including breaking changes) version of our heavily used php-fpm image could look like.

We figured that our old approach had some disadvantages (it was a php-fpm build based on [official docker php images](https://hub.docker.com/_/php)):

* it is based on a source build from php, so we could not use any packages from alpine/debian to speed up the build time
* there are differences between the php package on debian/alpine 
* there is no official alpine apache2 build
* we cannot add nginx unit to alpine build, as it lacks php embed SAPI [comment on php!1355](https://github.com/docker-library/php/pull/1355#issuecomment-1352087633)
* the non-alpine image has lots of (fixable) CVEs, we cannot fix (e.g. trivy image --ignore-unfixed php:8.1.13-fpm-buster says: Total: 23)

The new approach has some advantages:

* It uses the latest package distributed by alpine team/community (which is pretty fast when it comes to security updates - 1 or 2 days after release)
* The precompiled packages (e.g. xdebug) are very fast installed
* No need for custom scripts like [docker-php-ext-install](https://github.com/docker-library/php/blob/master/docker-php-ext-install)
* It ships with httpd binary (for apache2), unitd binary (for nginx unit) and php-fpm binary (for php fpm) to execute php web requests
* It ships linux/arm64/v8 and linux/amd64 version of the image
* The web server user is root, but web requests are executed as www-data
* The github release notes (including tool versions and php extension versions) is automatically generated if a commit is tagged
* The release is available only as exozet/draft-docker-php:8.1.13 (no suffix for -root, -xdebug -alpine or -sudo or others)
* The CI/CD pipeline includes tests to validate the image as nginx unit or apache2 delivery
* The CI/CD pipeline only builds the latest version (if necessary we can git checkout -b 8.1.13 if you really want to fix something in a release)

The new approach has also some disadvantages:

* It does not support debian. If we want to do it: we need to do the same approach for debian based on official repositories.
* We depend on the release of php packages at alpine (e.g. on 2023/01/03 the php82 was not officially packaged on alpine including nginx unit - so we cannot support it. at the same time it is available as docker image on official docker php)
* If the packaged package version number is not available on alpine anymore - we cannot recreate the docker image



# Contributing
Please refer to [CONTRIBUTING.md](CONTRIBUTING.md). 

# License
Please refer to [LICENSE.md](LICENSE.md). 

