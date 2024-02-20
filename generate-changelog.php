<?php
$imageName = $_SERVER['argv'][1];

$osReleaseDescription = file_get_contents('/etc/os-release');
$osNameAndVersion = 'unknown';
if(preg_match_all("/^PRETTY_NAME=\"(.+?)\"$/im",$osReleaseDescription,$matches)) {
    $osNameAndVersion = $matches[1][0];
}


?>
This docker image is based on the <?php echo $osNameAndVersion; ?> distribution and contains a list of tools and php extensions.

You can run this image via:

```
docker run --rm -it <?php echo $imageName; ?> php -v
```

and will get the version pasted.

<?php

echo PHP_EOL;
echo "# tools " . PHP_EOL;
echo PHP_EOL;

$output = shell_exec('apk info -v | sort -n');

$packageNamesToExpose = [
    'apache2',
    'bash',
    'bzip2',
    'composer',
    'curl',
    'git',
    'git-lfs',
    'msmtp',
    'mysql-client',
    'openssh-client-default',
    'rsync',
    'sshpass',
    'unit',
    'unzip',
    'vim',
    'wget',
];

if(preg_match_all("/^(.+)-([^-]+-[^-]+)$/im",$output,$matches)) {
    foreach ($matches[1] as $pos => $key) {
        if (in_array($key, $packageNamesToExpose)) {
            echo "- $key (" . $matches[2][$pos] . ')' . PHP_EOL;
        }
    }
}

$extensionNames = get_loaded_extensions();
sort($extensionNames);

$extensionFileNameSizeMap = [];

foreach (glob(ini_get('extension_dir') . "/*.so") as $filePath) {
    $fileName = basename($filePath);
    $extensionFileNameSizeMap[$fileName] = ceil(filesize($filePath) / 1024 / 1024) . 'MB';
}

echo PHP_EOL;
echo "# php extensions" . PHP_EOL;
echo PHP_EOL;

foreach ($extensionNames as $extensionName) {
    $ext = new ReflectionExtension($extensionName);
    $fileSizeSuffix = '';

    if (array_key_exists($extensionName . '.so', $extensionFileNameSizeMap)) {
        $fileSizeSuffix = ', ' . $extensionFileNameSizeMap[$extensionName . '.so'];
    }
    echo "- $extensionName (" . $ext->getVersion() . "$fileSizeSuffix)" . PHP_EOL;

    ob_start();
    $ext->info();
    $extInfo = ob_get_clean();

    if(preg_match_all("/^(.* [Vv]ersion.+).*=> (.+?)$/im",$extInfo,$matches)) {
        foreach ($matches[1] as $pos => $key) {
            echo "  - $key(" . $matches[2][$pos] . ")" . PHP_EOL;
        }
    }
}

if (file_exists('previous-php-i.txt')) {
  echo PHP_EOL;
  # we want to see what the php version this php -i was created from
  $previousPhpVersion = trim(shell_exec('cat previous-php-i.txt | grep "PHP Version" | head -n 1 | cut -f 4 -d " "'));
  # we want to pull php -i but ignore after environment (because it's not sorted properly)
  shell_exec('php -i | sed \'/^Environment$/,$d\' > /tmp/current-php-i.txt');
  # we diff the stripped php -i from previous and the current php version
  $diff = shell_exec('diff previous-php-i.txt /tmp/current-php-i.txt');
  echo "# `php -i` diff compared to php:" . $previousPhpVersion . PHP_EOL;
  echo PHP_EOL;
  echo '```diff' . PHP_EOL;
  echo $diff;
  echo '```' . PHP_EOL;
}

