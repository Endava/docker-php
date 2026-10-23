<?php

declare(strict_types=1);

/*
 * Points every release line in README.md to its latest published GitHub release.
 *
 * A release is only picked up once the security scan has uploaded all report
 * assets to it, so the README never links to a missing badge or report.
 *
 * Usage: php update-readme-releases.php <README.md> <releases.jsonl>
 *
 * releases.jsonl holds one {"tag": "...", "assets": ["..."]} object per line.
 * Every updated line is printed as "old -> new".
 */

const REQUIRED_ASSETS = ['vulnerability-report.html', 'vulnerability-status.png', 'size-status.png'];
const TAG_PATTERN = '/^(\d+\.\d+)\.(\d+)(-[a-z-]+)?$/';

if ($argc !== 3) {
    \fwrite(\STDERR, "Usage: php update-readme-releases.php <README.md> <releases.jsonl>\n");
    exit(1);
}

[, $readmePath, $releasesPath] = $argv;

$readme = \file_get_contents($readmePath);
$releaseLines = \file($releasesPath, \FILE_IGNORE_NEW_LINES | \FILE_SKIP_EMPTY_LINES);

if ($readme === false || $releaseLines === false) {
    \fwrite(\STDERR, "Could not read the README or the releases file.\n");
    exit(1);
}

// latest fully published patch version per release line, e.g. "8.5-ubuntu" => ["patch" => 12, "tag" => "8.5.12-ubuntu"]
$latest = [];

foreach ($releaseLines as $releaseLine) {
    $release = \json_decode($releaseLine, true, 512, \JSON_THROW_ON_ERROR);

    if (\preg_match(TAG_PATTERN, $release['tag'], $match) !== 1) {
        continue;
    }

    if (\array_diff(REQUIRED_ASSETS, $release['assets']) !== []) {
        continue;
    }

    $line = $match[1] . ($match[3] ?? '');
    $patch = (int) $match[2];

    if (!isset($latest[$line]) || $patch > $latest[$line]['patch']) {
        $latest[$line] = ['patch' => $patch, 'tag' => $release['tag']];
    }
}

\preg_match_all('/^\[release_(\w+)_link\]: \S+\/releases\/tag\/(\S+)$/m', $readme, $links, \PREG_SET_ORDER);

foreach ($links as [, $key, $currentTag]) {
    if (\preg_match(TAG_PATTERN, $currentTag, $match) !== 1) {
        continue;
    }

    $line = $match[1] . ($match[3] ?? '');

    if (!isset($latest[$line]) || $latest[$line]['patch'] <= (int) $match[2]) {
        continue;
    }

    $newTag = $latest[$line]['tag'];

    // only touch the link definitions of this release line, e.g. [size_85ubuntu_badge]: ...
    $readme = \preg_replace_callback(
        '/^\[\w+_' . \preg_quote($key, '/') . '_(?:badge|link)\]: .*$/m',
        static fn (array $definition): string => \preg_replace('#/' . \preg_quote($currentTag, '#') . '(?=/|$)#', '/' . $newTag, $definition[0]),
        $readme,
    );

    echo $currentTag . ' -> ' . $newTag . \PHP_EOL;
}

\file_put_contents($readmePath, $readme);
