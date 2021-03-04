$ytdl = "youtube-dl.exe"

$archiveDir = "D:\mpv\downloaded.txt"
$archive = "--download-archive", "$archiveDir"

$uploader = "%(uploader)s"

$outputDir = "D:\video\"
$outputTitle = "%(title)s.%(ext)s"
$outputPlaylist = "%(playlist)s/%(playlist_index)s - "

function ConvertFrom-Json20([object] $item){ 
    add-type -assembly system.web.extensions
    $ps_js = new-object system.web.script.serialization.javascriptSerializer
    return ,$ps_js.DeserializeObject($item)
}

Function download([string]$url) {
    $output = $outputTitle

    $Joutput = cmd /c $ytdl --no-warnings -J $url --add-header "Referer: $url"
    
    $data = ConvertFrom-Json20 $Joutput
    
    if ($data._type -eq "playlist") {
        $output = $outputPlaylist + $output
    }
    
    if ($data.uploader) {
        $output = $uploader + "/" + $output
    }
    
    $output = $outputDir + $output

    #Write-Output $data
    
    if ($data.id -eq "shell") {
        $archive = ""
    }
    
    & $ytdl --no-warnings $archive --no-overwrites --ignore-errors -o $output $url --add-header "Referer: $url" 
}

$link = $args[0] -replace "watch\?v=.*&list=", "playlist?list="

download $link
