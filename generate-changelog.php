<?php
?>
This docker image contains a list of tools and extensions.

<?php
$extensionNames = get_loaded_extensions();
sort($extensionNames);

$extensionFileNameSizeMap = [];

foreach (glob(ini_get('extension_dir') . "/*.so") as $filePath) {
    $fileName = basename($filePath);
    $extensionFileNameSizeMap[$fileName] = ceil(filesize($filePath) / 1024 / 1024) . 'MB';
}

echo "o extensions:" . PHP_EOL;

foreach ($extensionNames as $extensionName) {
    $ext = new ReflectionExtension($extensionName);
    $fileSizeSuffix = '';

    if (array_key_exists($extensionName . '.so', $extensionFileNameSizeMap)) {
        $fileSizeSuffix = ', ' . $extensionFileNameSizeMap[$extensionName . '.so'];
    }
    echo "   o $extensionName (" . $ext->getVersion() . "$fileSizeSuffix)" . PHP_EOL;

    ob_start();
    $ext->info();
    $extInfo = ob_get_clean();

    if(preg_match_all("/^(.* [Vv]ersion.+).*=> (.+?)$/im",$extInfo,$matches)) {
        foreach ($matches[1] as $pos => $key) {
            echo "      o $key(" . $matches[2][$pos] . ")" . PHP_EOL;
        }
    }
}

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
            echo " o $key (" . $matches[2][$pos] . ')' . PHP_EOL;
        }
    }
}