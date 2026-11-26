/*
  Totem Admin · jazykové mutace (CZ, SK, EN, ES)
  Admin se píše česky. Tahle vrstva překládá vykreslené texty rozhraní
  podle slovníku v admin/i18n.js (řádek = [cs, sk, en, es]).
  - přesná shoda textu, nebo vzor s {0}, {1}… (proměnné části se překládají znovu)
  - u vzoru jde říct, které proměnné musí být číslo (pátý prvek řádku, např. '01')
  - text spojený " · " nebo více řádků se překládá po částech
  - hlídá změny stránky (MutationObserver), takže funguje i pro okna a hlášky
  - prvek s atributem data-noi18n se nepřekládá
*/
(function () {
  var LANGS = { cs: 'CZ', sk: 'SK', en: 'EN', es: 'ES' };
  var LOCALE = { cs: 'cs-CZ', sk: 'sk-SK', en: 'en-US', es: 'es-DO' };
  var IDX = { cs: 0, sk: 1, en: 2, es: 3 };
  var KEY = 'totem-admin-lang';
  var ATTRS = ['placeholder', 'aria-label', 'title', 'alt'];
  var exact = Object.create(null), pats = [], cache = new Map();
  var NUM = /^[−+-]?[\d\s.,:–]+$/;  /* pátý prvek řádku: které proměnné musí být číslo, např. '01' */

  function load(rows) {
    rows.forEach(function (r) {
      if (r[0].indexOf('{0}') < 0) { exact[r[0]] = r; return; }
      var lit = r[0].replace(/\{\d\}/g, '');
      var src = r[0].replace(/[.*+?^$()|[\]\\]/g, '\\$&').replace(/\{(\d)\}/g, '(.+?)').replace(/[{}]/g, '\\$&');
      pats.push({ re: new RegExp('^' + src + '$'), r: r, w: lit.length, num: r[4] || '', dot: r[0].indexOf(' · ') >= 0 });
    });
    pats.sort(function (a, b) { return b.w - a.w; });
  }

  function pickLang() {
    try { var l = localStorage.getItem(KEY); if (LANGS[l]) return l; } catch (e) {}
    var n = (navigator.language || '').slice(0, 2).toLowerCase();
    return LANGS[n] ? n : 'cs';
  }
  var lang = pickLang();

  function core(s, l) {
    var r = exact[s];
    if (r) return r[IDX[l]] || s;
    var dot = s.indexOf(' · ') > 0;  /* text s tečkami: nejdřív vzory s tečkou, jinak po částech */
    for (var i = 0; i < pats.length; i++) {
      if (dot && !pats[i].dot) continue;
      var m = s.match(pats[i].re);
      if (!m) continue;
      if (pats[i].num && !pats[i].num.split('').every(function (k) { return NUM.test(m[+k + 1]); })) continue;
      return (pats[i].r[IDX[l]] || pats[i].r[0]).replace(/\{(\d)\}/g, function (_, k) { return tr(m[+k + 1], l); });
    }
    if (s.indexOf('\n') >= 0) return s.split('\n').map(function (x) { return tr(x, l); }).join('\n');
    if (s.indexOf(' · ') > 0) return s.split(' · ').map(function (x) { return tr(x, l); }).join(' · ');
    return s;
  }
  function tr(s, l) {
    l = l || lang;
    if (l === 'cs' || s == null) return s;
    s = String(s);
    if (!/[A-Za-zÀ-ž]/.test(s)) return s;
    var ck = l + '\u0001' + s;
    if (cache.has(ck)) return cache.get(ck);
    var m = s.match(/^(\s*)([\s\S]*?)(\s*)$/);
    var out = m[1] + core(m[2], l) + m[3];
    cache.set(ck, out);
    return out;
  }

  /* původní český text si každý uzel pamatuje, aby šlo přepínat tam i zpět */
  function doText(n) {
    var src = n.__src != null && n.nodeValue === n.__tr ? n.__src : n.nodeValue;
    var out = tr(src);
    n.__src = src; n.__tr = out;
    if (n.nodeValue !== out) n.nodeValue = out;
  }
  function doAttrs(el) {
    var mem = el.__a || (el.__a = {});
    for (var i = 0; i < ATTRS.length; i++) {
      var a = ATTRS[i], v = el.getAttribute(a);
      if (v == null) continue;
      var m = mem[a], src = m && v === m[1] ? m[0] : v, out = tr(src);
      mem[a] = [src, out];
      if (v !== out) el.setAttribute(a, out);
    }
  }
  function skip(el) { return el.closest && el.closest('[data-noi18n],script,style'); }
  function walk(root) {
    if (!root) return;
    if (root.nodeType === 3) { if (root.parentElement && !skip(root.parentElement)) doText(root); return; }
    if (root.nodeType !== 1 || skip(root)) return;
    doAttrs(root);
    var w = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT, {
      acceptNode: function (n) {
        if (n.nodeType === 1) return n.hasAttribute('data-noi18n') || n.tagName === 'SCRIPT' || n.tagName === 'STYLE' ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
        return NodeFilter.FILTER_ACCEPT;
      }
    });
    var n;
    while ((n = w.nextNode())) { if (n.nodeType === 3) doText(n); else doAttrs(n); }
  }

  var obs = new MutationObserver(function (list) {
    obs.disconnect();
    list.forEach(function (m) {
      if (m.type === 'characterData') walk(m.target);
      else if (m.type === 'attributes') { if (!skip(m.target)) doAttrs(m.target); }
      else m.addedNodes.forEach(walk);
    });
    watch();
  });
  function watch() { obs.observe(document.body, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ATTRS }); }

  function setLang(l) {
    if (!LANGS[l]) return;
    lang = l;
    try { localStorage.setItem(KEY, l); } catch (e) {}
    document.documentElement.lang = l;
    obs.disconnect(); walk(document.body); watch();
    document.querySelectorAll('[data-alang]').forEach(function (b) { b.setAttribute('aria-pressed', b.dataset.alang === l); });
  }

  window.TotemI18n = {
    LANGS: LANGS, load: load, tr: tr, setLang: setLang,
    lang: function () { return lang; },
    locale: function () { return LOCALE[lang]; },
    start: function () { setLang(lang); }
  };
})();
