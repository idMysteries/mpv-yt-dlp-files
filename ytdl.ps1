$ytdl = "yt-dlp.exe"
$directory = "D:\video\"

$archive = ""
$output = "%(title)s.%(ext)s"
$outputPlaylist = "%(playlist)s/%(playlist_index)s - "

$url = $args[0] -replace "watch\?v=.*&list=", "playlist?list="
$url = $url -replace "\?utm_source=player&utm_medium=video&utm_campaign=EMBED", ""

$meta = cmd /c $ytdl --print "%(playlist_id)s <<>> %(playlist_title)s <<>> %(uploader)s <<>> %(id)s" --no-download-archive --no-mark-watched --playlist-end 1 $url

$plid, $pltitle, $vuploader, $vid = $meta -Split " <<>> "

if ($url -match "twitch.tv/.*/clips") {
    $vuploader = $plid
}

if (($pltitle -eq "Queue") -or ($pltitle -eq "Watch later")) {
    $output = "$uploader/%(playlist_index)s - $output"
}
else {
    if ($pltitle -ne "NA") {
        $output = $outputPlaylist + $output
    }

    if ($vuploader -ne "NA") {
        $output = $vuploader + "/" + $output
    }

    if ($vid -eq "shell") {
        $archive = "--no-download-archive"
    }
}

& $ytdl $archive -o "$directory$output" $url
