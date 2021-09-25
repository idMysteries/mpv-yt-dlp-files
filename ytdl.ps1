$ytdl = "yt-dlp.exe"
$directory = "D:\video\"

$uploader = "%(uploader)s"
$archive = ""
$output = "%(title)s.%(ext)s"
$outputPlaylist = "%(playlist)s/%(playlist_index)s - "

$url = $args[0] -replace "watch\?v=.*&list=", "playlist?list="
$url = $url -replace "\?utm_source=player&utm_medium=video&utm_campaign=EMBED", ""

$pltitle = cmd /c $ytdl --print playlist_title --no-mark-watched --playlist-end 1 $url
$vuploader = cmd /c $ytdl --print uploader --no-mark-watched --playlist-end 1 $url
$vid = cmd /c $ytdl --print id --no-mark-watched --playlist-end 1 $url

if (($pltitle -eq "Queue") -or ($pltitle -eq "Watch later")) {
    $output = "$uploader/%(playlist_index)s - $output"
}
else {
    if ($pltitle -ne "NA") {
        $output = $outputPlaylist + $output
    }

    if ($vuploader -ne "NA") {
        $output = $uploader + "/" + $output
    }

    if ($vid -eq "shell") {
        $archive = "--no-download-archive"
    }
}

& $ytdl $archive -o "$directory$output" $url
