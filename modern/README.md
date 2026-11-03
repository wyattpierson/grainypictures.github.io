# A new cut of Grainy Pictures

A separate, buildless preview in `/modern/`. Original archive pages and assets stay in place; the legacy homepage’s Criterion and Reel Paradise destinations have been corrected. No external fonts, dependencies, or analytics are required. The viewing guide uses optional JavaScript for search.

## Preview

From the repository root run `python3 -m http.server 8080`, then open http://localhost:8080/modern/. Serving the root also makes the original assets and archive links available. A plain static server does not process the legacy pages’ Jekyll includes.

Pages: index.html, split-screen.html, book.html, john.html, janet.html. Shared styles: style.css. All paths are relative so this section works under a GitHub Pages base path.

## Content notes

Biographies and imagery come from the existing site. Janet’s expanded timeline cites SXSW’s 2022 leadership transition and 2023 awards announcement directly on her page. Current board memberships were omitted because they need fresh confirmation. The book page distinguishes the 2004 Reloaded edition from the UT Press edition of the original title.

The old Criterion collection URL returned 404 during research on October 26, 2026. The new viewing guide replaces the homepage and series-page search buttons with a curated list of current direct video links; see the viewing guide notes below.

## Later cutover

This preview is not published by this change. Keep it at `/modern/` for review. Before changing the homepage, preserve the original root homepage at a stable archive URL and update archive links in these new pages to that URL. Keep the other original paths and assets in place: moving the whole legacy tree would break historical links. Then promote the new homepage and adjust its relative links. Do not simply overwrite the root homepage with modern/index.html.

The existing `_config.yml` declares `source: public_html`, which is not present in this checkout. Verify the actual GitHub Pages build settings before deployment; this change intentionally leaves existing hosting configuration untouched.

## Verification

All five pages were checked for missing local links and image paths. The homepage was visually inspected in the in-app browser. Responsive layouts are included, but mobile device rendering has not been manually verified.

## Split Screen viewing guide

`watch-split-screen.html` follows Criterion’s ten viewing seasons, with ten introductions, 61 full episodes, and ten additional videos. Every entry connects to the original episode details and credits; all 66 original numbers are accounted for, including the combined Kevin Smith entry and four additional archive entries. Links were checked against the current Criterion search and direct video pages on November 2, 2026. The historical segment index comes from the original local episode guide. Season Two’s unnumbered Wes Anderson interview follows Episode 5, as in Criterion’s Season Two listing.

Edit `split-screen-guide.json`, then run `python3 modern/scripts/build-watch-guide.py` from the repository root to regenerate the static HTML. Recheck Criterion links when updating the data. The page works without JavaScript; `watch-guide.js` adds search across titles, original numbers, and archived segment names. Shared preview navigation is taken from `split-screen.html` when regenerating. The homepage links to both this guide and Criterion search; the series page links to the guide.

Viewing guide verification: all 81 direct video URLs returned HTTP 200 and matching video metadata. Local links and anchors were checked; desktop layout, expanded credits, person search, original-number search, empty results, clearing, and season navigation were checked in the in-app browser. Mobile CSS is included; mobile rendering has not been manually inspected.
