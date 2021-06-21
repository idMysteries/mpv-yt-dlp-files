$ytdl = "youtube-dl.exe"
$directory = "D:\video\"

$uploader = "%(uploader)s"

$output = "%(title)s.%(ext)s"
$outputPlaylist = "%(playlist)s/%(playlist_index)s - "

$archive = "--download-archive", "D:\mpv\downloaded.txt"

function ConvertFrom-Json20([object] $item){ 
    add-type -assembly system.web.extensions
    $ps_js = new-object system.web.script.serialization.javascriptSerializer
    $ps_js.MaxJsonLength = 104857600
    return ,$ps_js.DeserializeObject($item)
}

$url = $args[0] -replace "watch\?v=.*&list=", "playlist?list="
$url = $url -replace "\?utm_source=player&utm_medium=video&utm_campaign=EMBED", ""

$json = cmd /c $ytdl --no-warnings -J $url --add-header "Referer: $url"
$data = ConvertFrom-Json20 $json

#CRQueue is a queue on YouTube
#WL - Watch Later
if (($data.title -eq "Queue") -or ($data.id -eq "WL")) {
    $output = "$uploader/%(playlist_index)s - $output"
}
else {
    if ($data._type -eq "playlist") {
        $output = $outputPlaylist + $output
    }

    if ($data.uploader) {
        $output = $uploader + "/" + $output
    }

    if ($data.id -eq "shell") {
        $archive = ""
    }
}

& $ytdl --no-warnings --no-overwrites --ignore-errors $archive -o "$directory$output" $url --add-header "Referer: $url" 
