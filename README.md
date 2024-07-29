# My yt-dlp powershell script & mpv config for SSD disk

Run: ytdl [DRIVE LETTER] \<url\> \<yt-dlp-args\>

``` ps1
ytdl https://www.youtube.com/watch?v=dQw4w9WgXcQ --add-metadata
# download with metadata
```

``` ps1
ytdl D https://www.youtube.com/watch?v=dQw4w9WgXcQ --no-write-subs
# download to drive D (D:\Videos\) without subs
```

Settings for silent video viewing from HDD (in my case, this is an external drive, the main one is SSD). It helps a lot to watch movies in silence without hearing the HDD noise.
