#!/usr/bin/env bash
#
#  fetch-assets.sh — pull every asset off the old Canva site and lay it out
#                    under the clean paths that index.html expects.
#
#  ####################################################################
#  #  RUN THIS WHILE THE OLD CANVA SITE IS STILL LIVE.                #
#  #  keysfromabove.com/_assets/ is the ONLY source for these files.  #
#  #  Once the Canva site is taken down they are gone. Run this,      #
#  #  commit the assets, and only THEN switch the domain over.        #
#  ####################################################################
#
#  Usage:   ./scripts/fetch-assets.sh
#
#  Requires: curl, python3.
#  Strongly recommended: ffmpeg (video compression + image crops).
#  Optional: ImageMagick, cwebp.
#
#  Reads:  assets-manifest.json        the hash -> semantic-path mapping
#  Writes: assets/                     what the site actually uses
#          assets/_source/             verbatim originals, hash filenames
#          assets/_archive/            the 96 unused files, verbatim
#          assets/_contact-sheet.html  open this to eyeball the mapping
#
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="https://keysfromabove.com/_assets"
MANIFEST="assets-manifest.json"
KEYRING_FRAME=2   # which frame of the 3-frame key-ring sprite to use (0, 1 or 2)

command -v curl    >/dev/null || { echo "need curl";    exit 1; }
command -v python3 >/dev/null || { echo "need python3"; exit 1; }

HAVE_FFMPEG=0; command -v ffmpeg >/dev/null && HAVE_FFMPEG=1
HAVE_CWEBP=0;  command -v cwebp  >/dev/null && HAVE_CWEBP=1
HAVE_IM=0;     (command -v magick >/dev/null || command -v convert >/dev/null) && HAVE_IM=1
IM=""
[[ $HAVE_IM -eq 1 ]] && IM=$(command -v magick || command -v convert)

mkdir -p assets/_source assets/_archive assets/img assets/video assets/icons

# ---------------------------------------------------------------------------
# 1. Download every source file once, keyed by its original hash name.
# ---------------------------------------------------------------------------
echo "==> Downloading source assets from $BASE"

python3 - "$MANIFEST" > /tmp/kfa_pairs.tsv <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
for a in m["assets"]:
    print(a["source"] + "\t" + a["target"])
PY

fail=0
while IFS=$'\t' read -r src tgt; do
  flat="assets/_source/$(echo "$src" | tr '/' '-')"
  if [[ -s "$flat" ]]; then
    printf '  cached  %s\n' "$src"
  elif curl -fsSL --retry 3 --retry-delay 2 -o "$flat" "$BASE/$src"; then
    printf '  ok      %s\n' "$src"
  else
    printf '  FAILED  %s\n' "$src" >&2
    fail=$((fail + 1))
  fi
done < /tmp/kfa_pairs.tsv

if [[ $fail -gt 0 ]]; then
  echo
  echo "!! $fail asset(s) failed to download."
  echo "!! If these 404, the Canva site may already be down. Check before continuing."
  echo
fi

# ---------------------------------------------------------------------------
# 2. Copy the identified ones into their semantic paths.
# ---------------------------------------------------------------------------
echo "==> Mapping assets to semantic paths"
while IFS=$'\t' read -r src tgt; do
  flat="assets/_source/$(echo "$src" | tr '/' '-')"
  [[ -s "$flat" ]] || continue
  mkdir -p "$(dirname "$tgt")"
  cp "$flat" "$tgt"
done < /tmp/kfa_pairs.tsv

# ---------------------------------------------------------------------------
# 3. Crop the key-ring sprite.
#
#    Canva exported the logo's key-ring as a 2400x800 SPRITE SHEET — three
#    800x800 frames side by side:
#      frame 0 = plain white disc
#      frame 1 = key-ring on a white centre
#      frame 2 = key-ring on a transparent centre   <-- the one we want
#
#    Skip this and the logo renders as three overlapping circles.
# ---------------------------------------------------------------------------
if [[ -f assets/img/logo-keyring.png ]]; then
  echo "==> Cropping key-ring sprite (frame $KEYRING_FRAME of 3)"
  cp assets/img/logo-keyring.png /tmp/keyring-sprite.png
  OFF=$((800 * KEYRING_FRAME))

  if [[ $HAVE_IM -eq 1 ]]; then
    "$IM" /tmp/keyring-sprite.png -crop "800x800+${OFF}+0" +repage assets/img/logo-keyring.png
    echo "    cropped to 800x800"
  elif [[ $HAVE_FFMPEG -eq 1 ]]; then
    ffmpeg -y -loglevel error -i /tmp/keyring-sprite.png \
      -vf "crop=800:800:${OFF}:0" assets/img/logo-keyring.png
    echo "    cropped to 800x800"
  else
    echo "    !! No ImageMagick or ffmpeg — sprite NOT cropped."
    echo "    !! The ring logo will render as three overlapping circles."
  fi
fi

# ---------------------------------------------------------------------------
# 4. Compress the hero video. A looping background video has no business
#    being tens of megabytes.
# ---------------------------------------------------------------------------
if [[ -f assets/video/hero.mp4 && $HAVE_FFMPEG -eq 1 ]]; then
  echo "==> Compressing hero video"
  before=$(du -m assets/video/hero.mp4 | cut -f1)
  cp assets/video/hero.mp4 /tmp/hero-original.mp4

  ffmpeg -y -loglevel error -i /tmp/hero-original.mp4 -an \
    -vf "scale='min(1920,iw)':-2:flags=lanczos" \
    -c:v libx264 -profile:v high -preset slow -crf 30 \
    -pix_fmt yuv420p -movflags +faststart assets/video/hero.mp4

  ffmpeg -y -loglevel error -i /tmp/hero-original.mp4 -an \
    -vf "scale='min(1920,iw)':-2:flags=lanczos" \
    -c:v libvpx-vp9 -crf 38 -b:v 0 -row-mt 1 -deadline good -cpu-used 2 \
    assets/video/hero.webm

  ffmpeg -y -loglevel error -i assets/video/hero-poster.jpg \
    -vf "scale='min(1920,iw)':-2" -q:v 4 /tmp/poster.jpg
  mv /tmp/poster.jpg assets/video/hero-poster.jpg

  after_mp4=$(du -m assets/video/hero.mp4  | cut -f1)
  after_wbm=$(du -m assets/video/hero.webm | cut -f1)
  echo "    hero.mp4 : ${before}MB -> ${after_mp4}MB"
  echo "    hero.webm: ${after_wbm}MB"

  if [[ "$after_mp4" -gt 8 ]]; then
    echo
    echo "    !! hero.mp4 is still ${after_mp4}MB after compression."
    echo "    !! Shorten the loop (-t 8), drop to 720p, or raise -crf."
    echo "    !! See 'Heavy assets' in the README before committing."
    echo
  fi
elif [[ -f assets/video/hero.mp4 ]]; then
  sz=$(du -m assets/video/hero.mp4 | cut -f1)
  echo "==> ffmpeg NOT FOUND — hero video left uncompressed (${sz}MB)."
  echo "    Install ffmpeg and re-run before committing."
fi

# ---------------------------------------------------------------------------
# 5. Optimise the stills we actually use.
# ---------------------------------------------------------------------------
if [[ $HAVE_FFMPEG -eq 1 ]]; then
  echo "==> Optimising background images"
  for f in assets/img/bg-*.jpg; do
    [[ -f "$f" ]] || continue
    b=$(basename "$f")
    ffmpeg -y -loglevel error -i "$f" -vf "scale='min(2200,iw)':-2" -q:v 4 "/tmp/$b"
    mv "/tmp/$b" "$f"
  done
fi

if [[ $HAVE_CWEBP -eq 1 ]]; then
  echo "==> Emitting .webp siblings for backgrounds"
  for f in assets/img/bg-*.jpg assets/img/bg-*.png; do
    [[ -f "$f" ]] || continue
    cwebp -quiet -q 82 "$f" -o "${f%.*}.webp"
  done
fi

# ---------------------------------------------------------------------------
# 6. Favicon.
#
#    The original site's favicon is CANVA'S OWN "C" LOGO — Adelmar never set
#    a custom one. Shipping that would be daft, so we build one from the
#    key-ring instead.
# ---------------------------------------------------------------------------
if [[ -f assets/img/logo-keyring.png ]]; then
  echo "==> Generating a favicon from the key-ring logo"
  if [[ $HAVE_IM -eq 1 ]]; then
    "$IM" assets/img/logo-keyring.png -background none -resize 180x180 assets/icons/apple-touch-icon.png
    "$IM" assets/img/logo-keyring.png -background none -resize 32x32   assets/icons/favicon.png
  elif [[ $HAVE_FFMPEG -eq 1 ]]; then
    ffmpeg -y -loglevel error -i assets/img/logo-keyring.png -vf scale=180:180 assets/icons/apple-touch-icon.png
    ffmpeg -y -loglevel error -i assets/img/logo-keyring.png -vf scale=32:32   assets/icons/favicon.png
  else
    cp assets/img/logo-keyring.png assets/icons/favicon.png
    cp assets/img/logo-keyring.png assets/icons/apple-touch-icon.png
    echo "    (no resizer available — copied full-size)"
  fi
  echo "    assets/icons/favicon.png + apple-touch-icon.png"
fi

# ---------------------------------------------------------------------------
# 7. Contact sheet — so a human can sanity-check the mapping.
# ---------------------------------------------------------------------------
echo "==> Building assets/_contact-sheet.html"
python3 - "$MANIFEST" <<'PY'
import json, sys, html
m = json.load(open(sys.argv[1]))

rows = []
for a in m["assets"]:
    src  = a["source"]
    flat = "_source/" + src.replace("/", "-")
    ext  = src.rsplit(".", 1)[1].lower()
    if ext == "mp4":
        prev = '<video src="%s" muted loop playsinline onmouseover="this.play()" onmouseout="this.pause()"></video>' % flat
    else:
        prev = '<img src="%s" loading="lazy" alt="">' % flat
    cls = "used" if a["used_by_site"] else "spare"
    rows.append(
        '<figure class="%s">%s<figcaption><b>%s</b><span class="c">%s</span>'
        '<code>%s</code><code class="t">%s</code></figcaption></figure>'
        % (cls, prev, html.escape(a["describes"]), a["confidence"],
           html.escape(src), html.escape(a["target"]))
    )

style = (
 "body{background:#111;color:#eee;font:14px/1.5 system-ui,sans-serif;margin:2rem}"
 ".note{background:#2a1c3a;border-left:3px solid #9805ff;padding:1rem;max-width:60rem}"
 ".grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:1rem;margin-top:2rem}"
 "figure{margin:0;background:#1c1c22;border-radius:8px;padding:.6rem;border:2px solid transparent}"
 "figure.used{border-color:#9805ff}figure.spare{opacity:.5}"
 "img,video{width:100%;height:150px;object-fit:contain;border-radius:4px;background:#2a2a2a}"
 "figcaption{margin-top:.5rem;font-size:11px;word-break:break-all}"
 "code{display:block;color:#8ab;font-size:10px}code.t{color:#b98ae0}"
 ".c{float:right;text-transform:uppercase;font-size:9px;opacity:.7}"
)

note = (
 '<div class="note">'
 '<p><b>Purple border</b> = actually used by the site. Faded = archived spare.</p>'
 '<p>Every mapping here was checked by eye against the live site. If something still looks '
 'wrong, edit <code>assets-manifest.json</code> and re-run <code>./scripts/fetch-assets.sh</code> '
 '(downloads are cached, so it is fast).</p>'
 '<p>Careful: some Canva PNGs are <b>sprite sheets</b> with several frames side by side. '
 'If an image looks like repeated copies of itself, it needs cropping.</p>'
 '</div>'
)

doc = ('<!DOCTYPE html><meta charset="utf-8">'
       '<title>Keys From Above - asset contact sheet</title>'
       '<style>' + style + '</style>'
       '<h1>Asset contact sheet</h1>' + note +
       '<div class="grid">' + "".join(rows) + '</div>')

open("assets/_contact-sheet.html", "w").write(doc)
print("    open assets/_contact-sheet.html in a browser")
PY

echo
echo "==> Done."
du -sh assets 2>/dev/null | sed 's/^/    total: /'
echo
echo "    NEXT: open assets/_contact-sheet.html and check the purple-bordered tiles."
