$ytdl = "D:\mpv\yt-dlp.exe"
$directory = "D:\video\"
$datedir = Get-Date -Format "\\dd.MM.yyyy\\"

$uploader = "%(uploader)s"
$archive = "--download-archive", "D:\mpv\downloaded.txt"
$metatitle = "--parse-metadata", "title:%(meta_title)s"
$output = "%(title)s [%(id)s].%(ext)s"
$outputPlaylist = "%(playlist)s/%(playlist_index)s - "

& $ytdl --update

$url = $args[0] -replace "watch\?v=.*&list=", "playlist?list="
$url = $url -replace "\?utm_source=player&utm_medium=video&utm_campaign=EMBED", ""

$null, $args = $args

$meta = cmd /c $ytdl --print "%(playlist_id)s <<>> %(playlist_title)s <<>> %(uploader)s <<>> %(id)s <<>> %(extractor)s" --no-download-archive --no-mark-watched --playlist-end 1 $url

$plid, $pltitle, $vuploader, $vid, $extractor = $meta -Split " <<>> "

if ($url -match "twitch.tv/.*/clips") {
    $uploader = $plid
}

if (($pltitle -eq "Queue") -or ($pltitle -eq "Watch later") -or ($plid -eq "WL")) {
    $output = "$uploader/%(playlist_index)s - $output"
}
else {
    if ($pltitle -ne "NA") {
        $output = $outputPlaylist + $output
    }
    
    if ($vuploader -ne "NA") {
        $output = $uploader + "/" + $output
    }

    if ($extractor -eq "generic") {
        $archive = "--no-download-archive"
    }
}

& $ytdl $archive $metatitle $args --concurrent-fragments 2 --live-from-start -o "$directory$datedir$output" $url
