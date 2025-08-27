### dependencies

```sh
brew install poppler ffmpegthumbnailer librsvg imagemagick bat
```

- **poppler** → super-fast, reliable PDF first-page thumbs (`pdftoppm`). Faster & cleaner than driving PDFs through ImageMagick/Ghostscript.
- **ffmpegthumbnailer** → tiny, instant video thumbnails. Lower startup overhead than full `ffmpeg` for “grab one frame”.
- **librsvg** → best-in-class SVG rasterizer (`rsvg-convert`), higher quality than ImageMagick for complex SVGs.
- **imagemagick** → optional utility (EXIF auto-orient, odd formats, fallback if librsvg isn’t available).
- **bat** → pretty text previews.

### chmod our script

```sh
chmod +x ~/.config/lf/lf_kitty_preview ~/.config/lf/lf_kitty_clean
```
