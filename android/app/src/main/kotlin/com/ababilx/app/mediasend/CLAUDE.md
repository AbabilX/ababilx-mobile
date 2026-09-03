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
MediaSendActivity
 ├─ gallery/GalleryView      MediaStore grid, numbered selection, Camera + Files
 ├─ review/ReviewView        pager + thumbnail rail + one caption + Send
 └─ editor/EditorView        pen / highlighter / blur / crop / rotate / undo
```

Back walks that stack; cancel returns `RESULT_CANCELED`.

`MediaSendChannel` (`com.ababilx.app/media_send`) is the only thing Dart sees:
`available` then `open` → `{caption, items:[{path,name,mime,size}]}` or null
for cancel. `MainActivity.onActivityResult` forwards to it and returns early
only when the request was ours.

## Rules that must stay true

- **Edits are instructions, never pixels.** `PickedItem` holds rotation, a
  normalised crop and a list of normalised `DrawOp`s. The preview and the
  exported JPEG are produced by the *same* `EditRender` functions, which is why
  a stroke drawn on a 1600 px preview lands correctly on a 3000 px export.
  Nothing is flattened until `MediaSendExport.export`.
- **An unedited item is copied, not re-encoded.** Sending a photo straight
  through must not cost a JPEG generation, and a video is never decoded.
- **Blur is painted with the photo.** The stroke's `Paint` carries a
  `BitmapShader` of the downscaled-then-upscaled image, so blurring needs no
  extra layer, no clip, and exports identically. Do not reach for RenderScript.
- **Every bitmap that leaves `MediaBitmaps` is EXIF-upright.** A canvas does
  not read the orientation tag; a stroke on a sideways preview would land in
  the wrong place on the file.
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
- The FileProvider authority `${applicationId}.mediasend.fileprovider` exposes
  **only** `cacheDir/mediasend/`, and exists solely so the camera app can write
  the shot it was asked for.

## Deliberate gaps

- **iOS keeps the Dart sheet** (`shared/media/media_grid_sheet.dart`). That
  path is still live and must keep working; it is also the fallback for an
  Android build where the channel is missing.
- **No text overlay, no stickers, no video trim.** Scope was set at
  "review + draw & crop tools".
- Video review shows a still frame with a play badge; it does not play inline.
- Reordering the rail by drag is not implemented — order is the tap order in
  the grid.
