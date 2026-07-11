# Keys From Above — static site

A hand-written static rebuild of [keysfromabove.com](https://www.keysfromabove.com), replacing the
Canva Sites original. No build step, no framework, no dependencies: one HTML file, one stylesheet,
and about thirty lines of optional JavaScript.

---

## Run this first

**`./scripts/fetch-assets.sh` must be run while the old Canva site is still live.**

`keysfromabove.com/_assets/` is the only place the images and video exist. The moment the Canva site
is taken down or the domain is repointed, they are gone and this repo renders as a black page.

```bash
git clone <your-repo-url> keysfromabove
cd keysfromabove

./scripts/fetch-assets.sh     # <-- BEFORE you touch the domain

python3 -m http.server 8000   # or: npx serve .
open http://localhost:8000
```

Then commit the assets, deploy, and only *then* repoint DNS.

The script needs `curl` and `python3`. It strongly wants **ffmpeg** (video compression, sprite
crops) and will happily use ImageMagick and `cwebp` if they're around. Without ffmpeg or
ImageMagick the ring logo will render as three overlapping circles — see
[Sprite sheets](#sprite-sheets-a-canva-gotcha).

---

## Structure

```
.
├── index.html               Everything. Six sections, in order.
├── css/styles.css           Design tokens at the top, then components, then responsive.
├── js/main.js               Footer year, scroll offsets, hero-video autoplay retry. Optional.
├── assets-manifest.json     Canva's hash filenames → readable paths. Source of truth.
├── scripts/fetch-assets.sh  Downloads, renames, crops, compresses.
├── vercel.json              Cache headers and clean URLs.
└── assets/
    ├── img/                 Backgrounds, logo layers, thumbnails.
    ├── video/               hero.mp4, hero.webm, hero-poster.jpg
    └── icons/               Favicon, social SVGs.
```

| # | id | Contents |
|---|---|---|
| 1 | `#hero` | Background video, title, tagline, three CTA pills |
| 2 | `#about` | Biography copy over a photo, signature |
| 3 | `#portfolio` | Releases (11 links), Interview, Biography, media kit |
| 4 | `#playlists` | Both Spotify embeds, Groover submission link |
| 5 | `#contact` | JotForm embed |
| 6 | `#meditations` | Meditation copy, three Insight Timer links, signature |

Old Canva deep links (`#page-0` … `#page-4`) still resolve — alias anchors are in the markup, so
existing inbound links keep working.

---

## Editing content

All copy lives in `index.html` as plain HTML. No CMS, no templating — find the text, change it.

**Add a release:**

```html
<li><a href="https://artists.landr.com/XXXXX" target="_blank" rel="noopener">Track Name</a></li>
```

**Swap a section background** — don't touch the HTML, change the path in `css/styles.css`:

```css
.section--about .section__bg { background-image: url("../assets/img/bg-about.png"); }
```

**Change colours** — every colour is a custom property at the top of `styles.css`:

```css
--c-purple:   #9805ff;   /* brand neon accent */
--c-lavender: #e1bffe;   /* pill buttons      */
--c-cream:    #faf2e9;   /* body copy         */
```

---

## Font substitutions

Two of the original fonts are licensed through Canva and **cannot legally be self-hosted**:

| Original | Role | Substitute | Licence |
|---|---|---|---|
| **Agrandir Wide** | Card headings, brand text | **Archivo** (`wdth` 110–125) | OFL, Google Fonts |
| **Amsterdam One** | Neon headings + signatures | **Parisienne** | OFL, Google Fonts |
| **Quicksand** | Nav, body, buttons | **Quicksand** — unchanged | OFL, Google Fonts |

Agrandir is a wide geometric grotesque; Archivo is a grotesque with a real width axis, so it can be
genuinely widened rather than faked with letter-spacing. Amsterdam One and Parisienne are both
flowing monoline signature scripts — Parisienne is a touch more formal. If you want something looser,
**Sacramento** or **Allura** drop straight in:

```css
--f-script: "Parisienne", cursive;   /* try: Sacramento, Allura, Great Vibes */
```

…and update the Google Fonts `<link>` in `index.html` to match.

---

## The neon headings are text now (this is a correction)

The first audit assumed the glowing script headings — *About me*, *Mediakit*, *Playlist Placement*,
*Get in Touch*, *Meditations* — were images. **They aren't.** On the original they're live text in
Amsterdam One with a CSS glow. There is no image asset for any of them.

So they're real `<h2>` elements here, set in Parisienne with a layered `text-shadow` glow. That's
better than the original plan in every way: they scale, stay crisp at any zoom, cost nothing to
download, and search engines and screen readers read them as headings.

---

## Sprite sheets (a Canva gotcha)

Several of Canva's PNG exports are **sprite sheets** — multiple frames side by side in one file.
The ring logo's key-ring is the one that matters: it's **2400×800, i.e. three 800×800 frames**
(plain disc / key-ring on white / key-ring on transparent).

`fetch-assets.sh` crops it to frame 2. If you skip that step the logo renders as three overlapping
circles. The frame is configurable at the top of the script:

```bash
KEYRING_FRAME=2   # 0, 1 or 2
```

The logo is also **not a single file** — Canva composed it from three stacked layers (wings, key-ring,
halo). `index.html` stacks them the same way, positioned in `.ring-logo` in the CSS.

---

## What changed from the original

**Fixed**

- `Meditiations` → **Meditations** (hero typo).
- `Synchronisities` → **Synchronicities** (two release titles; LANDR's own slug always said
  "synchronicities" — only the label was misspelt).
- The Spotify playlist was a **static screenshot** — not clickable, showing a stale save count.
  Now **two live embeds**: *Soft Piano* and *Keys To Stories*.
- Icon-only links (Facebook, three Insight Timer meditations, Interview, Biography) had no
  accessible names. All labelled.
- `PIANIST | COMPOSER | PRODUCER` was set in `#9805ff` on near-black — badly failing contrast. It's
  now lavender with a purple glow: same brand colour, actually legible.
- **The favicon was Canva's own "C" logo.** Adelmar never set a custom one. The script now generates
  a real favicon from the key-ring.
- No responsive layout at all — the original was a fixed 1920×768 canvas. Now fluid from 320px up.

**Rebuilt rather than ported**

- Neon headings, pill buttons and the "next section" dots are CSS, not images.
- Signatures are live text in the script font.
- Hero video is WebM + MP4 with a poster fallback, `muted`/`playsinline` so it autoplays on mobile,
  and `prefers-reduced-motion` is respected.

**Kept**

- Every word of copy, verbatim (apart from the two typos).
- The palette and type hierarchy.
- All eleven release links, the interview, biography, media kit, Groover link, Facebook, and the
  three Insight Timer meditations.
- The JotForm contact form, embedded directly instead of through Canva's proxy.

---

## Open questions

- **Instagram and TikTok logos are in the asset set, but no Instagram or TikTok links exist anywhere
  in the live site's markup.** The SVGs are fetched to `assets/icons/` and ready to wire up — if you
  want those in the footer, add them next to the Facebook link in `index.html`.
- **The Meditations background is a looping video on the original.** The rebuild uses a still frame
  (`bg-meditations.jpg`) instead: it's a busy magenta swirl behind a large block of text, and the
  motion fought the copy. Trivial to restore as a `<video>` if you disagree.
- **Middle name is a required field on the JotForm.** That's almost certainly not intended — worth
  fixing in JotForm itself.

---

## Heavy assets

The full asset set is roughly **200 MB**, overwhelmingly video. `fetch-assets.sh` compresses the hero
to H.264 CRF 30 + VP9, strips the (muted) audio track, and caps it at 1080p — which should land it in
single digits of megabytes.

**If the script warns that `hero.mp4` is still over 8 MB, don't just commit it:**

- **Shorten the loop.** Background video rarely needs more than 8–10s. Add `-t 8` to the ffmpeg calls.
- **Drop to 720p.** Change `min(1920,iw)` to `min(1280,iw)`. Behind an 85%-opacity scrim, nobody will notice.
- **Raise the CRF** to 32–34.
- **Drop the video.** The poster frame alone is a perfectly good hero.

GitHub warns above 50 MB per file and hard-rejects at 100 MB.

`assets/_source/` and `assets/_archive/` (the 96 unused originals) are **gitignored** — they're
re-fetchable from the manifest for as long as the Canva site is up. Since the Canva site is going
away, you may reasonably want them preserved: remove those lines from `.gitignore` and commit,
accepting the repo size.

---

## Deploying

**Vercel** (`vercel.json` is already configured):

```bash
npm i -g vercel
vercel --prod
```

Or import the repo at [vercel.com/new](https://vercel.com/new) — framework preset **Other**, build
command **none**, output directory **`.`**.

Then add `keysfromabove.com` and `www.keysfromabove.com` under **Settings → Domains** — *after* the
assets are fetched and committed.

GitHub Pages, Netlify and Cloudflare Pages all work identically: static directory, no build step.

---

## Third-party services

| Service | What it does | Where |
|---|---|---|
| **JotForm** | Contact form (id `261402863154049`, posts to `eu-submit.jotform.com`) | `#contact` |
| **Spotify** | Two playlist embeds | `#playlists` |
| **LANDR / Even** | Release smart-links | `#portfolio` |
| **Insight Timer** | Three guided meditations | `#meditations` |

Nothing needs a backend. If you ever drop JotForm, the form is five fields (name, email, message) and
Vercel Functions, Formspree or Netlify Forms would replace it in an afternoon.
