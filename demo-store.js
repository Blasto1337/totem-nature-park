/*
  Sdílená ukázková data pro web rezervací (reservar.html) a Totem Admin (admin/).
  Prototyp: objednávky i nastavení se ukládají jen do prohlížeče (localStorage),
  takže obě stránky musí běžet na stejné doméně a ve stejném prohlížeči.
  V ostré verzi tohle nahradí databáze a server (PayPal webhook, e-maily).
*/
(function () {
  var K_ORDERS = 'totem-demo-orders';
  var K_SETTINGS = 'totem-demo-settings';

  var TODAY = '19. 12.';
  var DAYS = [['So', '19. 12.'], ['Ne', '20. 12.'], ['Po', '21. 12.'], ['Út', '22. 12.'], ['St', '23. 12.'], ['Čt', '24. 12.'], ['Pá', '25. 12.']];
  var SLOTS = ['9:30', '13:00'];
  var CAP = 40;
  var PRICE = { ad: 80, ch: 45 };

  /* místa obsazená agenturami (rezervace mimo web) */
  var AG = {
    '19. 12.': { '9:30': 37, '13:00': 28 },
    '20. 12.': { '9:30': 24, '13:00': 18 },
    '21. 12.': { '9:30': 31, '13:00': 12 },
    '22. 12.': { '9:30': 16, '13:00': 22 },
    '23. 12.': { '9:30': 38, '13:00': 27 },
    '24. 12.': { '9:30': 20, '13:00': 0 },
    '25. 12.': { '9:30': 12, '13:00': 6 }
  };

  var SEED = [
    { code: 'TNP-2WZ8RA', name: 'Emma Becker', email: 'emma.becker@example.com', phone: '+49 151 555 0123', lang: 'DE', date: '19. 12.', slot: '13:00', ad: 2, ch: 0, inf: 0, st: 'zaplaceno', at: '19. 12.' },
    { code: 'TNP-9HB3KD', name: 'Carlos Méndez', email: 'carlos.mendez@example.com', phone: '+34 611 555 210', lang: 'ES', date: '19. 12.', slot: '13:00', ad: 2, ch: 1, inf: 0, st: 'zaplaceno', at: '18. 12.' },
    { code: 'TNP-8MJ2QS', name: 'Sofía Ramírez', email: 'sofia.r@example.com', phone: '+52 55 5555 0177', lang: 'ES', date: '23. 12.', slot: '13:00', ad: 2, ch: 0, inf: 1, st: 'zaplaceno', at: '18. 12.' },
    { code: 'TNP-6TF4VE', name: 'Liam Walsh', email: 'liam.walsh@example.com', phone: '+1 617 555 0164', lang: 'EN', date: '21. 12.', slot: '9:30', ad: 4, ch: 2, inf: 0, st: 'zaplaceno', at: '17. 12.' },
    { code: 'TNP-4QX7M2', name: 'Jana Smith', email: 'jana.smith@example.com', phone: '+1 305 555 0142', lang: 'EN', date: '19. 12.', slot: '9:30', ad: 2, ch: 0, inf: 0, st: 'pouzito', used: '9:24', at: '17. 12.' },
    { code: 'TNP-3RN9HX', name: 'Mark Peters', email: 'mark.peters@example.com', phone: '+44 7700 900123', lang: 'EN', date: '19. 12.', slot: '13:00', ad: 2, ch: 2, inf: 0, st: 'zruseno', at: '16. 12.' }
  ];
  var DEFAULT_SETTINGS = { mode: 'slot', closed: { '24. 12.|13:00': true } };

  function clone(x) { return JSON.parse(JSON.stringify(x)); }
  function read(k) { try { var s = localStorage.getItem(k); return s ? JSON.parse(s) : null; } catch (e) { return null; } }
  function write(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} }

  function load() { return read(K_ORDERS) || clone(SEED); }
  function save(list) { write(K_ORDERS, list); }
  function settings() { return read(K_SETTINGS) || clone(DEFAULT_SETTINGS); }
  function saveSettings(s) { write(K_SETTINGS, { mode: s.mode, closed: s.closed }); }
  function reset() { try { localStorage.removeItem(K_ORDERS); localStorage.removeItem(K_SETTINGS); } catch (e) {} }

  /* nezaplacená podržená místa po 15 minutách propadnou */
  function expire(list) {
    var now = Date.now(), changed = false;
    list.forEach(function (o) { if (o.st === 'drzi' && o.hold < now) { o.st = 'vyprselo'; changed = true; } });
    return changed;
  }

  function newCode() {
    var a = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789', c = 'TNP-';
    for (var i = 0; i < 6; i++) c += a[Math.floor(Math.random() * a.length)];
    return c;
  }

  function pax(o) { return o.ad + o.ch + o.inf; }
  function total(o) { return o.ad * PRICE.ad + o.ch * PRICE.ch; }
  function live(o) { return o.st !== 'zruseno' && o.st !== 'vyprselo'; }

  /* QR kód: knihovna qrcode-generator, bez ní náhledový obrazec */
  function qrSvg(t) {
    try {
      if (window.qrcode) { var q = qrcode(0, 'M'); q.addData(t); q.make(); return q.createSvgTag({ cellSize: 4, margin: 2, scalable: true }); }
    } catch (e) {}
    var h = 0, n = 25, r = '';
    for (var i = 0; i < t.length; i++) h = (h * 31 + t.charCodeAt(i)) >>> 0;
    function rnd() { h ^= h << 13; h >>>= 0; h ^= h >>> 17; h ^= h << 5; h >>>= 0; return h % 100; }
    for (var y = 0; y < n; y++) for (var x = 0; x < n; x++) {
      var f = (x < 7 && y < 7) || (x > n - 8 && y < 7) || (x < 7 && y > n - 8), on;
      if (f) { var fx = x < 7 ? x : x - (n - 7), fy = y < 7 ? y : y - (n - 7); on = fx === 0 || fx === 6 || fy === 0 || fy === 6 || (fx > 1 && fx < 5 && fy > 1 && fy < 5); }
      else on = rnd() < 48;
      if (on) r += '<rect x="' + x + '" y="' + y + '" width="1" height="1"/>';
    }
    return '<svg viewBox="-1 -1 ' + (n + 2) + ' ' + (n + 2) + '" fill="#2B1A15" role="img" aria-label="QR">' + r + '</svg>';
  }

  window.TotemDemo = {
    K_ORDERS: K_ORDERS, K_SETTINGS: K_SETTINGS,
    TODAY: TODAY, DAYS: DAYS, SLOTS: SLOTS, CAP: CAP, PRICE: PRICE, AG: AG, SEED: SEED,
    load: load, save: save, settings: settings, saveSettings: saveSettings, reset: reset,
    expire: expire, newCode: newCode, pax: pax, total: total, live: live, qrSvg: qrSvg
  };
})();
