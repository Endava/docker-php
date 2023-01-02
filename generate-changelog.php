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
docker run --rm -it <?php echo $imageName; ?> -v
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
