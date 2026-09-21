# Native media send (Android)

Signal's picker → review → editor flow, written in Kotlin. Shipped 2026-09-03.
Read this before touching anything under `mediasend/`.

## Why it is our code and not Signal's

Signal-Android is **AGPL-3.0-only**. `examples/Signal-Android` is a
reference-only checkout: read it, match the behaviour, never paste from it.
Everything here is written against the observed UX, not the source.

## Shape

One Activity, three screens, one shared bitmap cache:

```
MediaSendActivity          lifecycle only: permissions, picker results, export
 ├─ MediaSendRequest       what the caller asked for, read off the Intent once
 ├─ MediaSendNavigator     which screen is up, and where Back goes
 ├─ MediaSendWiring        every callback between the screens; owns `quality`
 ├─ MediaSendIntake        what arrives picked, and where it goes
 ├─ MediaSendPreview       what the pager and editor decode at
 ├─ MediaSendSelection     what is picked, and where each piece came from
 ├─ gallery/GalleryView    albums -> one album's grid, numbered selection
 │   ├─ GalleryAlbumPane   the folder list + the top-bar title that returns to it
 │   ├─ GalleryPaging      one album's rows, paged, reset on album change
 │   └─ GalleryChoices     what is picked, in tap order
 ├─ review/ReviewView      pager + rail + edit + quality + caption + Send
 │   ├─ AddMoreSheetView   "+" → Camera / Gallery / Files
 │   └─ QualitySheetView   Standard / High
 └─ editor/EditorView      pen / highlighter / blur / eraser / crop / rotate / undo
```

Review chrome icons (`ic_ms_back`, `ic_ms_send`, `ic_ms_draw`, `ic_ms_add`,
`ic_ms_play`, plus Add-sheet camera/gallery/file) are **HugeIcons strokeRounded**
path data exported as Android stroke vectors — same glyphs the Flutter composer
uses — not Material filled icons. Top-right is a red **Remove** pill
(`ms_remove_pill` + `ic_ms_hi_delete`), not a close X.

Back walks that stack; cancel returns `RESULT_CANCELED`.

**The picker opens on ALBUMS, not on a flat recent grid.** The composer's "+"
panel already draws a rail of your most recent media, so a Gallery button that
opened on a full-screen copy of that rail showed the same photos twice and gave
no route to the rest of the library — which is what a user reported as "gallery
opens recent images instead of the gallery". `GalleryAlbumPane` reads
`MediaGalleryQuery.folders` (Camera, All media, then the rest — the same order
and the same synthetic `ALL_MEDIA_BUCKET_ID` the Dart folder gallery uses), and
"All media" is the second row so the old behaviour is one tap away. Back inside
an album returns to the list before it leaves the flow, and **selection survives
the move** — `GalleryChoices` is never cleared by an album change, only the
grid's rows are. A device with no readable albums falls straight into All media,
because an empty folder list reads as a failed load.

**A page landing for the album you just left is dropped by generation, not by
luck.** `GalleryPaging.open` bumps a counter that every in-flight page checks
before appending; without it two albums mix in one grid.

**"+" opens a sheet, not the grid.** Camera, Gallery and Files are one tap
each. `+` used to drop straight into the library grid, which left the other two
reachable only from inside it — and, from a camera-started flow, revealed a
grid that had never been told to load.

**The grid loads lazily and that is load-bearing.** `GalleryView.start()` reads
MediaStore, and a flow opened at the camera may reach the grid for the first
time through the Add sheet — so every route to it goes through
`MediaSendNavigator.showGallery`, which calls back into `loadGalleryOnce`.
Revealing the grid without telling it to load is what produced an empty black
screen. The once-only flag is set when the read *begins*, not when the grid is
shown, so a refused permission does not leave it blank forever.

**The grid replaces, so non-grid items must be remembered.** `gallery.onNext`
reports the whole selection, which would otherwise wipe the camera shot the
user just took. `MediaSendSelection.remember` marks camera shots and handed-in
files; `mergeGrid` puts them back, reading the survivors off the review
screen's own list so an item deleted there stays deleted.

`MediaSendChannel` (`com.ababilx.app/media_send`) is the only thing Dart sees:
`available` then `open` → `{caption, quality, items:[{path,name,mime,size}]}`
or null for cancel. `MainActivity.onActivityResult` forwards to it and returns
early only when the request was ours.

## Four front doors, one review screen

`EXTRA_START` picks where the flow opens: `gallery` (the grid), `camera`,
`files`, or `review` over URIs the caller already holds. That last one is how a
share from another app gets the same edit tools — `share_review.dart` hands the
`content://` URIs straight in, and the reviewed files come back as real paths
that re-enter `SharedPayload` as `file://` URIs (`ShareIntakeBridge.materialize`
opens those through the same content resolver, so nothing downstream changes).

Rules for the non-gallery doors:

- **A cancelled picker closes the flow.** Opened at the camera or at Files
  there is no grid underneath, so `onPickerClosedEmpty` finishes rather than
  dropping the user into a library they did not ask for. Back from the review
  screen does the same. `MediaSendPickers.onNothing` exists only for this.
- **The camera door must ask for `CAMERA` first.** `ACTION_IMAGE_CAPTURE`
  normally needs no permission — but only for an app that does not *declare*
  `android.permission.CAMERA`. This one does (calls need it), and for a
  declaring app the system throws `SecurityException` out of
  `startActivityForResult` instead of opening the camera. Opened at the camera
  door that throw came from `onCreate` and took the whole process down, which
  is exactly what a user saw on first tap. `MediaSendPickers.openCamera` now
  requests the grant and re-enters from
  `MediaSendActivity.onRequestPermissionsResult`; both picker launches are
  additionally wrapped in `runCatching`, because no OEM Activity may be able to
  kill the app from inside `onCreate`.
- **Files partitions.** Pictures and videos go to the review screen; a PDF has
  nothing to review and waits in `passthrough`, exported with the album so one
  trip through Files is still one send.
- **URIs handed in need `FLAG_GRANT_READ_URI_PERMISSION` *and* `ClipData`.** A
  share's read grant covers the package, but an Activity started with the URI
  only in an extra is not covered by it — without the ClipData a shared photo
  opens as a blank page.

## Sent media quality

`MediaQuality` carries Signal's own numbers (`PushMediaConstraints.MediaConfig`
LEVEL_2 and LEVEL_3): Standard caps at 1.5 MB with targets
2048/1600/1024/768/512, High at 3 MB with 4096 down to 512, both at JPEG 75.
`MediaSendExport.encodeToFit` walks that ladder and keeps the first encode
under the cap.

- **Standard is the default**, and the setting lives in **Dart**
  (`shared/media/media_quality.dart`, SharedPreferences). The Activity receives
  it as `EXTRA_QUALITY` and echoes the chosen level back in the result; Dart
  writes it. Do not add a second store on this side — the review sheet and
  Settings → Media quality must not be able to disagree.
- **A picture that already fits is still copied, never re-encoded.**
  `needsShrinking` answers from a bounds decode and the file length, so the
  no-op case costs no full decode. This is the one rule below that changed:
  it used to be "an unedited item is always copied".
- **Video is never touched.** There is no transcoder here, so quality does not
  reach it. Say so in any UI that offers the choice.

## Rules that must stay true

- **Edits are instructions, never pixels.** `PickedItem` holds rotation, a
  normalised crop and a list of normalised `DrawOp`s. The preview and the
  exported JPEG are produced by the *same* `EditRender` functions, which is why
  a stroke drawn on a 1600 px preview lands correctly on a 3000 px export.
  Nothing is flattened until `MediaSendExport.export`.
- **An item that needs no change is copied, not re-encoded.** Sending a photo
  that already fits the chosen quality must not cost a JPEG generation, and a
  video is never decoded. See *Sent media quality* above for what "fits" means.
- **Blur is painted with the photo.** The stroke's `Paint` carries a
  `BitmapShader` of the downscaled-then-upscaled image, so blurring needs no
  extra layer, no clip, and exports identically. Do not reach for RenderScript.
- **The eraser is a stroke painted with the original photo** (`DrawTool.ERASER`),
  the same trick as blur. It covers whatever was drawn before it, undo drops
  it like any stroke, and it exports identically. It does not delete points
  from earlier strokes — that would break the instructions-not-pixels model.
- **Crop handles are sized in dp** (`CropBox(density)`): 4dp thick, 26dp arms,
  36dp touch slop. They were raw pixels, a hairline on a 3x screen.
- **Every bitmap that leaves `MediaBitmaps` is EXIF-upright.** A canvas does
  not read the orientation tag; a stroke on a sideways preview would land in
  the wrong place on the file.
- **Thumbnails come from `FastThumbnail` before anything is decoded.**
  `ContentResolver.loadThumbnail` hands back the thumbnail MediaProvider
  already generated for the system gallery — upright, cached, and an order of
  magnitude cheaper than the three `openInputStream` calls (bounds, pixels,
  EXIF) `MediaBitmaps.decode` costs. For a **video** it replaces a full
  `MediaMetadataRetriever` frame extraction, which is the larger win. It is
  capped at `MAX_PX = 512` on purpose: asked for more, the provider decodes the
  original anyway, sometimes upscaling a 512 px thumbnail to get there — so the
  review pager and the editor, which need real pixels to draw strokes onto,
  keep the full decode.
- **A selection tap repaints badges, it does not rebind cells.** Tapping one
  photo renumbers every photo after it, so the whole grid is notified — but
  with `GalleryAdapter.PAYLOAD_SELECTION`, and with
  `supportsChangeAnimations = false` on the grid. Without both, one tap
  re-requested the thumbnail of every visible cell *and* had DefaultItemAnimator
  cross-fade a second copy of each: about twenty inflations for a disc changing
  from "2" to "1". That was the reported "selecting images is slow".
- **Export runs on two lanes, not one and not one per core**
  (`MediaSendExport.exportAll`). Serial encoding froze Send for seconds on an
  album; one lane per core would hold four bitmaps at the quality level's
  largest target — 4096 px on High, about 50 MB each — and trade the stall for
  an OOM. Order is kept by reading the futures in submission order.
- **One `ThumbnailLoader` for all four screens.** `GalleryView.start` takes the
  Activity's, so a cell decoded in the grid is the bitmap the album cover asks
  for. It used to build its own, which meant two LruCaches at a quarter of the
  heap each.
- **`ThumbnailCache` downscales rather than decoding again.** The screens want
  four sizes of the same photo — grid at a third of the width, album covers at
  192, review rail at 160, pager and editor at the preview size — and a plain
  size-keyed cache misses every time, so picking one picture decoded it three
  times over. A miss now looks for the smallest cached copy *at least* as large
  and scales that down; only down, or the editor would get an upscaled blur to
  draw strokes onto.
- **A decode nothing is waiting for is cancelled, and two waiters share one.**
  Re-binding a cell releases its claim (`R.id.media_send_thumb_claim`), and the
  last claim leaving cancels the queued work — the URI tag alone only discarded
  the *result*, after a fling had already paid for every cell it passed. The
  in-flight table is what stops the review pager and its rail decoding the same
  photo twice when they bind together. All of that bookkeeping is main-thread;
  only the decode is on the pool.
- **A grid cell is tagged with the URI its decode is for**
  (`R.id.media_send_thumb_key`). Without that, recycling puts the wrong photo
  in the wrong cell.
- **`MediaSendPermissions.granted` is `any`, not `all`** — Android 14's
  *Selected photos* grant is access, and yields a smaller grid rather than a
  broken one. A refusal falls through to the document picker, which needs no
  permission of ours.
- **Cancel is not "unsupported".** Dart asks `isAvailable()` *before* `open()`;
  a null from `open` means the user backed out and must not fall through to the
  old Dart sheet.
- **Both sheets are Views in the review layout, not `BottomSheetDialog`s.**
  `MediaSendActivity` is a plain `android.app.Activity` with no Material theme,
  so a dialog would arrive unthemed and fighting its own window insets.
  `ReviewView.dismissSheet` closes whichever is open and is what Back consults
  first.
- **The edit button lives beside the caption, not in the top bar**, and hides
  on a video page: the editor exports a JPEG and `MediaSendExport` copies a
  video untouched, so an edit made on a video frame is silently discarded.
  Offering the button there would promise something the export throws away.
- **The caption is one message for the album**, not one per image — that is
  both Signal's current behaviour and the only shape `sendMessage` has (a body
  plus attachments). The review screen's Send actually sends: the composer
  calls `_send()` when `ComposerAttachResult.sendRequested` is set.
- `taskAffinity=""` is repeated on `MediaSendActivity`; aliases and activities
  do not inherit it, and without it picking a photo would open a second entry
  in recents.
- **The Activity draws edge-to-edge on every version**
  (`WindowCompat.setDecorFitsSystemWindows(window, false)` in
  `MediaSendActivity.onCreate`), so every chrome bar's own padding has to
  come from `MediaSendInsets.padTop`/`padBottom` — nothing pads it for free.
  Those two only **mark** a bar; the single listener that feeds them lives on
  the Activity root (`MediaSendInsets.install`) and walks down to the marks.
  Do not move it back to a listener per bar: a bar hears insets only if every
  ancestor dispatches them down, and these bars are inside `<merge>` blocks in
  sibling screens that are `GONE` most of the time and that mark themselves
  during `setContentView`, i.e. before attach — so the `requestApplyInsets`
  next to a mark never fires. The theme (`MediaSendThemeBase`, plus a
  `values-v29` override) turns on `windowDrawsSystemBarBackgrounds` with
  transparent bars and no contrast scrim, since the legacy parent theme would
  otherwise ignore the bar colours and keep them opaque.
  **No marked bar may have a fixed `layout_height`** — every one is
  `wrap_content` + a `minHeight` (56dp top, 72dp gallery footer). The inset
  arrives as padding, so on a fixed height it eats the interior and clips the
  44-52dp buttons against the system bar instead of growing the bar clear of
  it. That was the bug on the gallery footer after the top bars were fixed. Bottom chrome
  (gallery footer, review's rail+caption, editor's tool row) pads for the
  navigation bar and the IME together, so the caption field also rises clear
  of the keyboard.
- **The picture sits between the bars, never under them**
  (`MediaSendContentFit.chrome`, review pager and editor canvas). The bars
  used to float over a full-screen image, so a tall photo ran behind the
  close/done row and the tool row, and a stroke drawn there landed under a
  button. The content view takes margins equal to the bars' measured heights.
  The keyboard is not followed (the margin holds while it is up), and the
  editor's colour strip goes `INVISIBLE`, never `GONE`, so switching to blur
  or crop does not resize the picture.
- The FileProvider authority `${applicationId}.mediasend.fileprovider` exposes
  **only** `cacheDir/mediasend/`, and exists solely so the camera app can write
  the shot it was asked for.

## Deliberate gaps

- **iOS keeps the Dart sheet** (`shared/media/media_grid_sheet.dart`) and the
  plain camera/document pickers. That path is still live and must keep working;
  it is also the fallback for an Android build where the channel is missing.
  **Quality is Android-only** for the same reason — there is no Dart-side
  compressor, so an iOS send goes out at full size.
- **No view-once.** Signal's crossed-eye toggle in the review screen needs
  read-once semantics on the server; the button is deliberately absent rather
  than present and inert.
- **The attachment keyboard's rail still sends on tap**, with no review — that
  is Signal's behaviour too, and the point of the rail.
- **No text overlay, no stickers, no video trim.** Scope was set at
  "review + draw & crop tools".
- Video review shows a still frame with a play badge; it does not play inline.
- Reordering the rail by drag is not implemented — order is the tap order in
  the grid.
