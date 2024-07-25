$ytdl = "yt-dlp"
$directory = "F:/video/"
$datedir = Get-Date -Format "/dd.MM.yyyy/"

$params = @{
    Uploader = "%(uploader)s"
    Archive = @("--download-archive", "%APPDATA%\mpv\archive.txt")
    MetaTitle = @("--parse-metadata", "title:%(meta_title)s")
    Output = "%(title).160B [%(id)s].%(ext)s"
    OutputPlaylist = "/%(playlist)s/%(playlist_index)s - "
}

& $ytdl --update

$url = $args[0] -replace "watch\?v=.*&list=", "playlist?list="

$null, $args = $args

$meta = & $ytdl --print playlist_id,playlist_title,uploader,id,extractor --ignore-no-formats-error --no-download-archive --no-mark-watched --playlist-end 1 $url
$plid, $pltitle, $vuploader, $vid, $extractor = $meta -Split "\n"

if ($url -match "twitch.tv/.*/clips") {
    $params.Uploader = $plid
}

$output = if (($pltitle -eq "Queue") -or ($pltitle -eq "Watch later") -or ($plid -eq "WL")) {
    "$($params.Uploader)/%(playlist_index)s - $($params.Output)"
} else {
    $base = if ($pltitle -ne "NA") { $params.OutputPlaylist + $params.Output } else { $datedir + $params.Output }
    if ($vuploader -ne "NA") { $params.Uploader + $base } else { $base }
}

if ($extractor -eq "generic") {
    $params.Archive = "--no-download-archive"
}

$liveFromStart = if ($extractor -like "*youtube*") { "--live-from-start" } else { "" }

$indexParam = ""
if ($url -match "index=(\d+)") {
    $index = $matches[1]
    $indexParam = "-I ${index}:"
}

& $ytdl $params.Archive $params.MetaTitle --concurrent-fragments 4 $liveFromStart $indexParam $args -o "$directory$output" $url
