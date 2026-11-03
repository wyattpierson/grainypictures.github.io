"""Regenerate the buildless guide after editing split-screen-guide.json."""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
data = json.loads((ROOT / 'split-screen-guide.json').read_text())
esc = html.escape

def duration(seconds):
    return f'{seconds // 60}:{seconds % 60:02d}'

def archive_links(entries):
    return ' '.join(f'<span class="archive-pair">Original #{a["number"]}: <a href="{a["details"]}">Episode details</a>' + (f' · <a href="{a["credits"]}">Credits</a>' if a.get('credits') else '') + '</span>' for a in entries)

base = (ROOT / 'split-screen.html').read_text()
start = base[:base.index('<section class="page-head">')]
start = start.replace('<title>Split Screen — Grainy Pictures</title>', '<title>A guide to watching Split Screen — Grainy Pictures</title>')
start = start.replace('Explore John and Janet Pierson’s independent film television series Split Screen and its original episode archives.', 'Watch Split Screen in Criterion Channel order: ten seasons, John Pierson’s introductions, direct episode links, and original episode details and credits.')
start = start.replace('href="style.css">', 'href="style.css"><link rel="stylesheet" href="watch-guide.css"><script src="watch-guide.js" defer></script>')
start = start.replace('aria-current="page"', 'aria-current="true"')
parts = [start, '''<section class="guide-head">
<div><a class="guide-back" href="split-screen.html">← About the series</a><p class="eyebrow">Split Screen / The viewing guide</p><h1>A field guide<br>to <em>Split Screen.</em></h1><p class="intro">Ten seasons. A whole world of independent film.<br>Find your episode, press play, and follow the stories back to the people who made them.</p><a class="button" href="#season-1">Start with season 1 ↓</a></div>
<aside class="guide-note"><p class="eyebrow">Two ways into the same history</p><h2>Watch in Criterion order.<br><em>Keep the original story.</em></h2><p>Criterion’s seasons regroup the original IFC run. The season and episode labels here follow Criterion; “Original #” connects each entry to our historical guide and credits.</p><p>The <em>Projections</em> interviews appear throughout these viewing seasons, even though they aired later in the original run.</p><a href="#about-numbering">A note on the numbering ↓</a></aside></section>
<div class="guide-stats"><span><b>10</b> viewing seasons</span><span><b>61</b> full episodes</span><span><b>10</b> introductions by John Pierson</span></div>
<div class="guide-tools"><nav class="season-jumps" aria-label="Jump to Criterion season"><span>Season</span>''']
for s in data['seasons']:
    parts.append(f'<a href="#season-{s["number"]}" aria-label="Season {s["number"]}">{s["number"]:02d}</a>')
parts.append('''</nav><div class="guide-search" hidden><label for="episode-search">Find a person, film, or original episode number</label><div class="search-line"><input id="episode-search" type="search" placeholder="Try Wes Anderson, Blair Witch, or #41" autocomplete="off"><button type="button" id="clear-search">Clear</button></div><p id="search-status" class="fine" role="status" aria-live="polite"></p></div></div>
<div class="guide-seasons" id="episodes">''')
for season in data['seasons']:
    n = season['number']
    parts.append(f'<section class="guide-season" id="season-{n}" aria-labelledby="heading-{n}"><div class="season-heading"><div><p class="eyebrow">Criterion viewing order / {len(season["episodes"])} episodes + introduction</p><h2 id="heading-{n}">Season <em>{n:02d}.</em></h2></div><a href="#episodes" class="back-top">All seasons ↑</a></div>')
    parts.append(f'<div class="season-intro"><div class="intro-copy"><p class="eyebrow">Before you begin / {duration(season["intro"]["seconds"])}</p><p class="intro-title">John Pierson introduces Season {n}</p></div><a class="watch-intro" aria-label="Watch John Pierson’s introduction to Season {n} on Criterion" href="{season["intro"]["url"]}"><span aria-hidden="true">▶</span> Watch introduction <span aria-hidden="true">↗</span></a></div><ol class="episode-list">')
    for ep in season['episodes']:
        original = esc(' & '.join(f'#{a["number"]}' for a in ep['original']))
        label = esc(ep.get('display_label', f'S{n} · E{ep["episode"]}'))
        parts.append(f'<li class="guide-episode" id="s{n}-e{ep["episode"]}"><div class="episode-number" aria-label="Episode {ep["episode"]}">{ep["episode"]:02d}</div><div class="episode-body"><p class="episode-meta">{label} <span> / {duration(ep["seconds"])} / Original {original}</span></p><h3>{esc(ep["title"])}</h3><details><summary>Segments &amp; original credits</summary><p class="segment-index">{esc(ep["segments"])}</p>')
        if ep.get('note'):parts.append(f'<p class="episode-note">{esc(ep["note"])}</p>')
        parts.append(archive_links(ep['original']))
        parts.append(f'</details></div><a class="watch-episode" aria-label="Watch {esc(ep["title"])} on Criterion" href="{ep["url"]}">Watch <span aria-hidden="true">↗</span></a></li>')
    parts.append('</ol></section>')
parts.append('''</div><p id="no-results" class="no-results" hidden>No episodes match that search. Try a surname, film title, or original number such as #41.</p>
<section class="guide-context" id="about-numbering"><p class="eyebrow">The history stays here</p><h2>Different seasons.<br><em>The same Split Screen.</em></h2><div class="context-columns"><div><h3>Reading the guide</h3><p>Use the introductions as the starting point for each Criterion season. Episode labels follow the titles on Criterion, so an introduction never counts as Episode 1 here.</p><p>Season Two’s Wes Anderson interview is listed after Episode 5 on Criterion, without a season/episode label in its title. We place it sixth. Season Nine’s Kevin Smith entry links to both original episodes, #49 and #50.</p><p>Segment names are a compact index from our original guide. Open “Episode details” or “Credits” for the full historical record.</p></div><div><h3>More from the original run</h3><p>The original archive also includes these entries beyond the viewing list above:</p><ul class="archive-extras">''')
for a in data['archive_only']:
    parts.append(f'<li><a href="{a["details"]}">Original #{a["number"]} — {esc(a["title"])}</a>' + (f' · <a href="{a["credits"]}">Credits</a>' if a.get('credits') else '') + '</li>')
parts.append('''</ul><a class="text-link" href="../splitscreen2/epguide.html">Explore the full original episode guide ↗</a></div></div></section>
<section class="guide-extras"><p class="eyebrow">Keep exploring / Also on Criterion</p><h2>Flagged <em>clips.</em></h2><p>Trailer, individual segments, and a twentieth-anniversary conversation.</p><ul>''')
for extra in data['extras']:
    title = extra['title'].replace('SPLIT SCREEN: ', '').replace('Split Screen: ', '')
    parts.append(f'<li><a href="{extra["url"]}">{esc(title)} <span>{duration(extra["seconds"])} ↗</span></a></li>')
parts.append('''</ul></section><div class="guide-source"><p>Listing links checked November 2, 2026 against <a href="https://www.criterionchannel.com/search?q=split+screen">Criterion’s Split Screen search</a>. Season placement follows Criterion’s season listings, including <a href="https://www.criterionchannel.com/split-screen-season-two-1">Season Two</a>. Watching requires access to The Criterion Channel; availability may change.</p><p>Historical numbering and segment index: <a href="../splitscreen2/epguide.html">Grainy Pictures’ original episode guide</a>.</p></div>''')
parts.append(base[base.index('</main>'):])
(ROOT / 'watch-split-screen.html').write_text(''.join(parts))
