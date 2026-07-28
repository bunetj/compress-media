# compress images videos audio pdf - simple scripts for windows

made w llm ,just simple shit. i hope it's stable and reliable lol.

the **video** script is simple just creates a video_compressed efficiency okay quality okay. i don't have many videos.

the **audio** script looks okay too. i almost never used it bc my audios seem optimal.

**pdf** can be compressed by converting it to images and back to pdf idk if it's conventional or what. i didnt used it much and did not finish it.

* check sizes.txt for optimal sizes so as to avoid the neurotic battle for petty megabytes

---

below is more info exclusively about the **images** script bc it's complicated

## functions

```
-s n    select files > n MB
-r n    select files > n*1000 px in height/width (resolution)
-resize by 50% by default
-p n    by n %
-bit8
-jpg
-jpg -q

-replace        overwrites. otherwise puts in _compressed\ near
-recurse        looks in subfolders

-log    auto-created
```

note again there is no checker for whether it's optimal to compress the image it's all by hand with -s and -r etc i fucked up several times but i had a cloud backup or it was retrievable from the internet plus really i don't mind pixelating my childhood self a little.


## a little guide

how to compress images eg for a limited space and with much shit like useless screenshots

- in everything app search `type:image size:>2mb` to find heavy directoires
- resize (50%) if >2/3k: `-resize -s 2 (or 3)`
- copy by hand or don't use -replace, for a backup.
- compress all (not valuable) images to jpg without thinking. up to 90% compression. no visible quality change if it's not sth delicate. avoid handwriting and similar lines in not very high resolution, small text, transparent bgs, anyth of small resoln already, anyth valuable and delicate.
- convert png to bit8 (simplifies colors, visibly okay)


## alts

i forgot to look into them before. 

i found apps like caesium now. they overload my cpu.

i did not find universal scripts lk this after a quick search.

