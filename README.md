# compress media - simple scripts

made w ai


## dependencies

- ffmpeg
- magick


## overview

images: everyth below

video: creates video_compressed

audio: okay

pdf: unfinished


## images compression

```
-s n    files > n MB
-r n    files > n * 1000 px in resolution
-resize 50% by default
-p n    resize by percent
-bit8
-jpg
-q  quality for jpg

-replace    overwrites. otherwise backs up
-recurse    looks in subfolders

-log    auto created on errors
```

another thing is making a slideshow. options:

1. a video editor, eg shotcut

2. screen recording a slideshow, eg: xnview > slideshow (can display specified metadata) + obs

3. slideshow.ps1 (if same resolution)



## efficiency

jpg: a no-minder for useless images, up to 95%

resize: for large images (>2-3k)

bit8 (simplifies colors in png): up to 20%

## rational compression

use commands to select only files optimal for compression. have backups.

find heavy images in the system, eg in everything app search `type:image size:>2mb`

sizes.md shows optimal sizes

avoid jpg compression for all and other compression for some of those:

- small/handwritten text, drawn lines (pixelates to less readable/fine)
- transparent bg/elements (become colored)
- fine or valuable images (pixelates shades and the image)
- small resolution images (pixelates to lower quality)


## templates for commands

```
.\cmpr_IMGs.ps1 -jpg
.\cmpr_IMGs.ps1 -jpg -recurse
.\cmpr_IMGs.ps1 -jpg -s 1
.\cmpr_IMGs.ps1 -jpg -s 1 -recurse
.\cmpr_IMGs.ps1 -resize
.\cmpr_IMGs.ps1 -resize -r 2
.\cmpr_IMGs.ps1 -bit8
```


## alternatives

apps like caesium overload my computer.

i didn't find scripts like this one quickly.
