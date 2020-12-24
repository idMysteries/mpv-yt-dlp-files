$outputDir = "D:\video\"
$archiveDir = "D:\mpv\downloaded.txt"

$outputTemplatePlaylist = "%(uploader)s/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s"
$outputTemplate = "%(title)s.%(ext)s"

$script = "youtube-dl.exe"

$link = $args[0]

Function download([string]$url="",[bool]$isplaylist=$false) {
    $output = $outputTemplate
    
    if ($isplaylist -eq $true) {
        $output = $outputTemplatePlaylist
    }

    & $script --download-archive $archiveDir --no-overwrites --ignore-errors -o "$outputDir$output" $url
}

download $link (($link -like "*/playlist?*") -or ($link -like "*&list=*") -or ($link -like "*/playlists")  -or ($link -like "*youtube.com/*/videos"))
