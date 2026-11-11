---
name: generate-image
description: Generate an image via Bing Image Creator (bing.com/images/create) using Claude's built-in browser pane, then save it to disk. Use whenever the user asks to generate, create, or make an image, picture, icon, sprite, logo, or illustration.
---

Generate an image through Bing Image Creator and save it to disk.

Use the **built-in browser** (tools named `mcp__Claude_Browser__*`). Do not use Playwright or Claude in Chrome. The pane keeps its own sign-ins, so the user must be signed in to Microsoft there. Read the `anthropic-skills:built-in-browser` skill first if you have not this session. Tools are already loaded; if `tabs_context` says the pane is hidden, ask the user to show it.

## Flow

1. `navigate` to `https://www.bing.com/images/create/ai-image-generator` (or `preview_start` with that `url`).
2. Confirm the session is signed in: the header should show the account button and Rewards points, not "Sign in". If it is not signed in, stop and ask the user to sign in in the pane. Never enter credentials yourself. The user may have to approve the site first.
3. Find the composer with `find` ("Describe the image you want") and type the prompt (`form_input` or click + `type`).
4. Optionally set the `Mode` and `Aspect Ratio` comboboxes (`find` "Mode" / "Aspect Ratio", then `form_input`). Defaults are `Vivid and natural` and `3:2` (1248x832). Mode choices are typically "Vivid and natural" and "Realistic". Only change them if the user asked.
5. Click **Generate** (disabled until the composer has text). This navigates to `/images/create/ai-image-generator/<slug>/1-<id>`, whose page title is the prompt.
6. Wait for generation (about 20-60 s). Share, Download, Set as Wallpaper and Edit image are all disabled while generating. Poll with `find` "Download" and check for `[disabled]`; do not sleep blindly and do not click while disabled.
7. Save the image (see below) and report the saved path(s).

## Saving the image

Downloading a file needs the user's explicit permission. State the filename, source (bing.com) and approximate size, then ask, unless the original request already clearly asked for the image to be saved.

Preferred: click **Download** (`find` "Download" -> click). Bing saves `<prompt-slug>.jpg` (slug truncated) into the browser's download folder, normally `~/Downloads`. Confirm by looking for a `.jpg` there modified in the last few minutes rather than predicting the name. Clicking Download navigates the page to the per-image URL; that is normal.

If the pane does not download anything, fall back to reading the image URL and fetching it with a shell:

```js
// javascript_tool
document.querySelector('.aigc-display__img')?.src
```

Then `curl -L -o <path> "<url>"` (Bash). When the image is for this project, save it where the user wants it, usually under `src/Assets/`, not `~/Downloads`.

## Variations

Each generation returns a strip of 4 variations. Download applies to the **currently selected** one.

| Target | Selector |
| --- | --- |
| Thumbnail | `.aigc-batch__item` |
| Selected thumbnail | `.aigc-batch__item--active` |
| Main displayed image | `.aigc-display__img` |

Do not select thumbnails by accessible name: all four share the prompt as aria-label. Click by class plus index instead, e.g. via `javascript_tool`:

```js
document.querySelectorAll('.aigc-batch__item')[1].click()   // 0-based
```

Verify the selection moved before downloading:

```js
const items = [...document.querySelectorAll('.aigc-batch__item')];
'count=' + items.length +
' activeIndex=' + items.findIndex(b => b.classList.contains('aigc-batch__item--active')) +
' src=' + document.querySelector('.aigc-display__img')?.src
```

Repeat per variation: select, confirm `activeIndex`, save. Bing names every download after the prompt slug, so multiple downloads become `name.jpg`, `name (1).jpg`, ... Rename as you go and tell the user which is which. Compare sizes or hashes to prove two files are different.

## Rate limits and credits

Fast credits are given on first use, then generations consume boosts. If Download never becomes enabled, tell the user the boosts have probably run out instead of looping.

## Write vs generate

If the user asks you to *write* a prompt rather than produce an image, fill the composer and stop. Only click Generate when an image was actually requested.

## Notes

- Selectors were verified against the Bing UI in the original opencode skill; re-check with `find` if a step fails rather than guessing.
- Report the final saved file path to the user.
