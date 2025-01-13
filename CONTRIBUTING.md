# Contributing to docker-php

We love your input! We want to make contributing to this project as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features

## We Develop with Github

We use Github to host code, to track issues and feature requests, as well as accept pull requests.

## Pull Requests

Pull requests are the best way to propose changes to the codebase. We actively welcome your pull requests:

1. Fork the repo and create your branch from respective `release/*` branch.
2. If you've added code that should be tested, add tests.
6. Issue that pull request!

Always write a clear log message for your commits. One-line messages are fine for small changes, but bigger changes should look like this:

    $ git commit -m "A brief summary of the commit
    > 
    > A paragraph describing what changed and its impact."


## Any contributions you make will be under the Apache 2.0 Software License

When you submit code changes, your submissions are understood to be under the same [Apache 2.0](https://choosealicense.com/licenses/apache-2.0/) that covers the project. Feel free to contact the maintainers at [opensource@endava.com](opensource@endava.com) if that's a concern.

## Report bugs using Github's issues

We use Github issues to track public bugs. Report a bug by [opening a new issue]().

## Write bug reports with detail, background, and sample code

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

## Use a Consistent Coding Style

We use [Hadolint](https://github.com/hadolint/hadolint) for Dockerfile linting.

And also please consider to:
- run a ```hadolint Dockerfile``` to check for code quality violations

## Snippets for Special Case: Build pecl package manually and fitness function check for availability

If you need to build (e.g. pecl amqp) manually, because the package does not exist yet in packages, you have to do two things:

1. add the fitness function at e.g. [.github/workflows/fitness-functions-release-8.4.yml](.github/workflows/fitness-functions-release-8.4.yml) a section for this (the example is for alpine:3.21 and the package php84-pecl-amqp)

```yaml
  packages-not-available-on-alpine-for-community-release-8-4:
    name: Package not available on alpine for php 8.4 in community, yet
    runs-on: ubuntu-latest
    strategy:
      matrix:
        package:
          - php84-pecl-amqp
    steps:
      -   name: Execute
          run: "! docker run --rm alpine:3.21 apk --no-cache search ${{ matrix.package }} | grep ${{ matrix.package }}"
  packages-not-available-on-alpine-testing-for-release-8-4:
    name: Package not available on alpine 3.21 for php 8.4, yet
    runs-on: ubuntu-latest
    strategy:
      matrix:
        package:
          - php84-pecl-amqp
    steps:
      -   name: Execute
          run: "! docker run --rm alpine:3.21 apk --no-cache search ${{ matrix.package }}  | grep ${{ matrix.package }}"
```

2. add the package like this in the Dockerfile at the respective part:

```Dockerfile
# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-amqp
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers rabbitmq-c-dev ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" pecl84 install amqp \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/amqp.so \
    && echo "extension=amqp" > /etc/$PHP_PACKAGE_BASENAME/conf.d/40_amqp.ini \
    && apk del --no-network .build-deps \
    && apk add --no-cache rabbitmq-c
```

And as soon as the fitness function fails - remove the "FIXME: " and remove the manual apk add command. That's it!

## License
By contributing, you agree that your contributions will be licensed under Apache 2.0 License.

## References
This document was adapted from the open-source contribution guidelines for [Facebook's Draft](https://github.com/facebook/draft-js/blob/a9316a723f9e918afde44dea68b5f9f39b7d9b00/CONTRIBUTING.md) and [https://gist.github.com/briandk/3d2e8b3ec8daf5a27a62](https://gist.github.com/briandk/3d2e8b3ec8daf5a27a62)

# Code of Conduct

Please refer to [Code of Conduct](CODE_OF_CONDUCT.md)
