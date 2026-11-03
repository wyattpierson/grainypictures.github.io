// The complete viewing guide and all links remain available without JavaScript.
(() => {
  const search = document.querySelector('#episode-search');
  const seasons = [...document.querySelectorAll('.guide-season')];
  const entries = [...document.querySelectorAll('.guide-episode')];
  const normalize = text => text.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[’‘]/g, "'").toLowerCase();
  const index = new Map(entries.map(entry => [entry, normalize(entry.textContent)]));
  document.querySelector('.guide-search').hidden = false;
  function filter() {
    const terms = normalize(search.value.trim()).split(/\s+/).filter(Boolean);
    let count = 0;
    for (const entry of entries) {
      entry.hidden = !terms.every(term => index.get(entry).includes(term));
      if (!entry.hidden) count++;
    }
    for (const season of seasons) {
      season.hidden = ![...season.querySelectorAll('.guide-episode')].some(entry => !entry.hidden);
    }
    document.querySelector('#no-results').hidden = count > 0;
    document.querySelector('#search-status').textContent = terms.length ? `${count} of ${entries.length} episodes match` : `${entries.length} episodes · Search titles, segment names, and original numbers`;
  }
  search.addEventListener('input', filter);
  document.querySelector('#clear-search').addEventListener('click', () => { search.value = ''; filter(); search.focus(); });
  document.querySelectorAll('a[href^="#season-"], .back-top').forEach(link => link.addEventListener('click', () => { search.value = ''; filter(); }));
  filter();
})();
