$ytdl = "youtube-dl.exe"
$archiveDir = "D:\mpv\downloaded.txt"

$uploader = "%(uploader)s"

$outputDir = "D:\video\"
$outputTitle = "%(title)s.%(ext)s"
$outputPlaylist = "%(playlist)s/%(playlist_index)s - "

Function download([string]$url="",[bool]$isPlaylist=$false) {
    $output = $outputTitle
    
    if ($isPlaylist -eq $true) {
        $output = $outputPlaylist + $output
    }
    
    if (($url -like "*youtube.com*") -or ($url -like "*youtu.be*")) {
        $output = $uploader + "/" + $output
    }

    $output = $outputDir + $output

    & $ytdl --download-archive $archiveDir --no-overwrites --ignore-errors -o $output $url
}

$link = $args[0]

download $link (($link -like "*/playlist?*") -or
                ($link -like "*&list=*") -or
                ($link -like "*/playlists") -or
                ($link -like "*/videos"))
