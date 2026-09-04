#!/bin/bash

set -e

MODULE_OUTPUT=$(docker run --pull=never --rm "$DOCKER_REGISTRY_IMAGE" php -m 2>&1)

if echo "$MODULE_OUTPUT" | grep -F "Module \"pcntl\" is already loaded" > /dev/null
then
  echo "PHP loaded PCNTL more than once" >&2
  echo "$MODULE_OUTPUT" >&2
  exit 1
fi

docker run --pull=never --rm "$DOCKER_REGISTRY_IMAGE" php -r '
if (!extension_loaded("pcntl") || !function_exists("pcntl_fork")) {
    fwrite(STDERR, "PCNTL is not available\n");
    exit(1);
}

$pid = pcntl_fork();
if ($pid === -1) {
    fwrite(STDERR, "pcntl_fork() failed\n");
    exit(2);
}
if ($pid === 0) {
    exit(0);
}

if (pcntl_waitpid($pid, $status) !== $pid || !pcntl_wifexited($status) || pcntl_wexitstatus($status) !== 0) {
    fwrite(STDERR, "The forked process did not exit successfully\n");
    exit(3);
}
'
