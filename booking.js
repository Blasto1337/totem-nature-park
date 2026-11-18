/* Rezervace na webu: výběr termínu, údaje, platba (simulace PayPalu), vstupenka s QR. */
(function () {
  var D = window.TotemDemo;
  var root = document.getElementById('bk');
  var side = document.getElementById('bkSide');
  var layer = document.getElementById('bkLayer');
  if (!D || !root) return;

  var L = {
    es: {
      steps: ['Fecha', 'Datos', 'Pago', 'Entradas'],
      wd: { So: 'sáb', Ne: 'dom', Po: 'lun', 'Út': 'mar', St: 'mié', 'Čt': 'jue', 'Pá': 'vie' }, mon: 'dic',
      choose_day: 'Elige el día', tour: 'Excursión guiada', morning: 'Mañana', afternoon: 'Tarde',
      left: function (n) { return n === 1 ? 'queda 1 plaza' : 'quedan ' + n + ' plazas'; },
      left_short: function (n) { return n + ' libres'; },
      sold: 'Agotado', closed: 'Cerrado',
      free_entry: 'Entrada libre: ven cuando quieras entre las 9:00 y las 17:00. Alimentación a las 9:45 y a las 13:15.',
      tickets: 'Entradas', adult: 'Adulto', child: 'Niño', infant: 'Menor de 2 años', gratis: 'gratis',
      total: 'Total', cont: 'Continuar', only: function (n, f) { return 'Solo quedan ' + n + ' plazas para ' + (f ? 'este día' : 'esta excursión') + '.'; },
      details: 'Tus datos', name: 'Nombre y apellido', email: 'Correo electrónico', wa: 'WhatsApp', hotel: 'Hotel para la recogida',
      hotel_ph: 'Opcional', terms: 'Acepto las normas del parque. Cancelación gratuita hasta 24 h antes de la visita.',
      back: 'Atrás', to_pay: 'Continuar al pago', err_form: 'Rellena tu nombre y un correo válido.', err_full: 'Mientras tanto se agotaron las plazas. Elige otra fecha.',
      hold: 'Guardamos tus plazas durante', pay_pp: 'Pagar con PayPal', pay_card: 'Tarjeta de débito o crédito',
      card_note: 'Puedes pagar con tarjeta sin tener cuenta de PayPal.',
      paid: 'Pago recibido. ¡Tus entradas van en camino!',
      see_you: function (n) { return '¡Nos vemos en la selva, ' + n + '!'; },
      show_qr: 'Muestra este código QR en la entrada. Un solo código para todo el grupo.',
      sent: function (e) { return 'También te lo enviamos a ' + e + ' y por WhatsApp.'; },
      date: 'Fecha', entry: 'Entrada', any_time: 'Cuando quieras, 9:00 a 17:00', paid_l: 'Pagado',
      t_ad: function (n) { return n + (n === 1 ? ' adulto' : ' adultos'); },
      t_ch: function (n) { return n + (n === 1 ? ' niño' : ' niños'); },
      t_inf: function (n) { return n + ' menor de 2'; },
      new_b: 'Nueva reserva', expired: 'El tiempo para pagar ha terminado y las plazas se liberaron.',
      sum_title: 'Tu reserva', incl: ['Excursión de 3,5 h con guía', 'Alimentación de los animales incluida', 'Recogida en tu hotel de Uvero Alto', 'Cancelación gratuita hasta 24 h antes'],
      pp_title: 'PayPal · simulación', pp_note: 'Demo: en la versión real aquí se abre la ventana segura de PayPal. Los datos de la tarjeta nunca pasan por nuestro servidor.',
      pp_pay: 'Pagar', pp_fail: 'Simular tarjeta rechazada', pp_close: 'Cerrar', declined: 'Tarjeta rechazada. Tus plazas siguen reservadas.',
      select: 'Elige fecha y entradas'
    },
    en: {
      steps: ['Date', 'Details', 'Payment', 'Tickets'],
      wd: { So: 'Sat', Ne: 'Sun', Po: 'Mon', 'Út': 'Tue', St: 'Wed', 'Čt': 'Thu', 'Pá': 'Fri' }, mon: 'Dec',
      choose_day: 'Choose a day', tour: 'Guided tour', morning: 'Morning', afternoon: 'Afternoon',
      left: function (n) { return n === 1 ? '1 spot left' : n + ' spots left'; },
      left_short: function (n) { return n + ' left'; },
      sold: 'Sold out', closed: 'Closed',
      free_entry: 'Open entry: come any time between 9:00 and 17:00. Feeding sessions at 9:45 and 13:15.',
      tickets: 'Tickets', adult: 'Adult', child: 'Child', infant: 'Under 2', gratis: 'free',
      total: 'Total', cont: 'Continue', only: function (n, f) { return 'Only ' + n + ' spots left for this ' + (f ? 'day' : 'tour') + '.'; },
      details: 'Your details', name: 'Full name', email: 'E-mail', wa: 'WhatsApp', hotel: 'Hotel for pick-up',
      hotel_ph: 'Optional', terms: 'I agree to the park rules. Free cancellation up to 24 h before the visit.',
      back: 'Back', to_pay: 'Continue to payment', err_form: 'Please enter your name and a valid e-mail.', err_full: 'These spots just sold out. Please choose another date.',
      hold: 'We are holding your spots for', pay_pp: 'Pay with PayPal', pay_card: 'Debit or credit card',
      card_note: 'You can pay by card without a PayPal account.',
      paid: 'Payment received. Your tickets are on the way!',
      see_you: function (n) { return 'See you in the jungle, ' + n + '!'; },
      show_qr: 'Show this QR code at the entrance. One code for the whole group.',
      sent: function (e) { return 'We also sent it to ' + e + ' and on WhatsApp.'; },
      date: 'Date', entry: 'Entry', any_time: 'Any time, 9:00 to 17:00', paid_l: 'Paid',
      t_ad: function (n) { return n + (n === 1 ? ' adult' : ' adults'); },
      t_ch: function (n) { return n + (n === 1 ? ' child' : ' children'); },
      t_inf: function (n) { return n + ' under 2'; },
      new_b: 'New booking', expired: 'Time to pay ran out and the spots were released.',
      sum_title: 'Your booking', incl: ['3.5-hour guided excursion', 'Animal feeding included', 'Pick-up at your Uvero Alto hotel', 'Free cancellation up to 24 h before'],
      pp_title: 'PayPal · simulation', pp_note: 'Demo: in the live version the secure PayPal window opens here. Card details never touch our server.',
      pp_pay: 'Pay', pp_fail: 'Simulate declined card', pp_close: 'Close', declined: 'Card declined. Your spots are still held.',
      select: 'Choose a date and tickets'
    }
  };

  var lang = window.TOTEM_LANG || 'es';
  var orders = D.load();
  var cfg = D.settings();
  var w = { step: 1, date: D.TODAY, slot: '13:00', ad: 2, ch: 0, inf: 0, name: '', email: '', phone: '', hotel: '', code: null, err: '' };

  function t() { return L[lang] || L.es; }
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function free() { return cfg.mode === 'free'; }
  function sync() { orders = D.load(); cfg = D.settings(); if (D.expire(orders)) D.save(orders); }
  function closed(d, s) { return s ? !!cfg.closed[d + '|' + s] : D.SLOTS.every(function (x) { return cfg.closed[d + '|' + x]; }); }
  function used(d, s) {
    var base = s ? ((D.AG[d] || {})[s] || 0) : D.SLOTS.reduce(function (a, x) { return a + ((D.AG[d] || {})[x] || 0); }, 0);
    return base + orders.filter(function (o) { return o.date === d && D.live(o) && (!s || o.slot === s); }).reduce(function (a, o) { return a + D.pax(o); }, 0);
  }
  function left(d, s) { return closed(d, s) ? 0 : (s ? D.CAP : D.CAP * D.SLOTS.length) - used(d, s); }
  function dayLabel(d) { var x = D.DAYS.filter(function (z) { return z[1] === d; })[0]; return (x ? t().wd[x[0]] + ' ' : '') + parseInt(d, 10) + ' ' + t().mon; }
  function slotName(s) { return s === '9:30' ? t().morning : t().afternoon; }
  function current() { return w.code ? orders.filter(function (o) { return o.code === w.code; })[0] : null; }
  function holdLeft(o) { var s = Math.max(0, Math.round(((o.hold || 0) - Date.now()) / 1000)); return Math.floor(s / 60) + ':' + ('0' + s % 60).slice(-2); }
  function toast(m) { var d = document.createElement('div'); d.className = 'bk-toast'; d.setAttribute('role', 'status'); d.textContent = m; document.body.appendChild(d); setTimeout(function () { d.remove(); }, 2600); }

  function ticketsLine(o) {
    var p = [t().t_ad(o.ad)];
    if (o.ch) p.push(t().t_ch(o.ch));
    if (o.inf) p.push(t().t_inf(o.inf));
    return p.join(', ');
  }
  function rows(o, withPaid) {
    return '<div class="bk-rows">' +
      '<div class="bk-row"><div class="grow"><small>' + t().date + '</small></div><b>' + dayLabel(o.date) + '</b></div>' +
      '<div class="bk-row"><div class="grow"><small>' + (o.slot ? t().tour : t().entry) + '</small></div><b>' + (o.slot ? slotName(o.slot) + ', ' + o.slot : t().any_time) + '</b></div>' +
      '<div class="bk-row"><div class="grow"><small>' + t().tickets + '</small></div><b>' + ticketsLine(o) + '</b></div>' +
      (withPaid ? '<div class="bk-row"><div class="grow"><small>' + t().paid_l + '</small></div><b>$' + D.total(o) + '</b></div>' : '') +
      '</div>';
  }

  function stepsHtml() {
    return '<div class="bk-steps">' + t().steps.map(function (n, i) {
      return '<span class="' + (i + 1 === w.step ? 'on' : i + 1 < w.step ? 'done' : '') + '">' + (i + 1) + '. ' + n + '</span>';
    }).join('') + '</div>';
  }

  function step1() {
    var f = free(), s = f ? null : w.slot;
    var l = s === undefined || (!f && !s) ? 0 : left(w.date, s);
    var n = D.pax(w), ok = n > 0 && n <= l;
    var days = D.DAYS.map(function (x) {
      var d = x[1];
      var lft = f ? left(d, null) : D.SLOTS.reduce(function (a, z) { return a + Math.max(0, left(d, z)); }, 0);
      var note = closed(d, null) ? t().closed : lft <= 0 ? t().sold : t().left_short(lft);
      return '<button class="bk-pick" data-day="' + d + '" aria-pressed="' + (w.date === d) + '"' + (lft <= 0 ? ' disabled' : '') + '><small>' + t().wd[x[0]] + '</small><b>' + parseInt(d, 10) + '</b><small>' + note + '</small></button>';
    }).join('');
    var slots = f ? '<p class="bk-note">' + t().free_entry + '</p>' :
      '<h3>' + t().tour + '</h3><div class="bk-slots">' + D.SLOTS.map(function (z) {
        var lz = left(w.date, z), c = closed(w.date, z);
        return '<button class="bk-pick" data-slot="' + z + '" aria-pressed="' + (w.slot === z) + '"' + (lz <= 0 ? ' disabled' : '') + '><span><small>' + slotName(z) + '</small><b>' + z + '</b></span><small>' + (c ? t().closed : lz <= 0 ? t().sold : t().left(lz)) + '</small></button>';
      }).join('') + '</div>';
    var qty = [['ad', t().adult, '$' + D.PRICE.ad], ['ch', t().child, '$' + D.PRICE.ch], ['inf', t().infant, t().gratis]].map(function (r) {
      return '<div class="bk-row"><div class="grow"><b>' + r[1] + '</b><small>' + r[2] + '</small></div><span class="bk-qty"><button data-q="' + r[0] + ':-1" aria-label="−1 ' + r[1] + '">−</button><span>' + w[r[0]] + '</span><button data-q="' + r[0] + ':1" aria-label="+1 ' + r[1] + '">+</button></span></div>';
    }).join('');
    return stepsHtml() + '<h3>' + t().choose_day + '</h3><div class="bk-days">' + days + '</div>' + slots +
      '<h3>' + t().tickets + '</h3><div class="bk-rows">' + qty + '</div>' +
      '<div class="bk-total"><span>' + t().total + '</span><b>$' + D.total(w) + '</b></div>' +
      (n > l ? '<p class="bk-err">' + t().only(Math.max(0, l), f) + '</p>' : '') +
      (w.err ? '<p class="bk-err">' + w.err + '</p>' : '') +
      '<button class="bk-btn dark full" data-act="s2"' + (ok ? '' : ' disabled') + '>' + t().cont + '</button>';
  }

  function step2() {
    return stepsHtml() + '<h2>' + t().details + '</h2>' +
      '<form class="bk-form" id="bkForm" novalidate>' +
      '<label>' + t().name + '<input id="fN" autocomplete="name" value="' + esc(w.name) + '" required></label>' +
      '<label>' + t().email + '<input id="fE" type="email" autocomplete="email" value="' + esc(w.email) + '" required></label>' +
      '<label>' + t().wa + '<input id="fP" type="tel" autocomplete="tel" value="' + esc(w.phone) + '"></label>' +
      '<label>' + t().hotel + '<input id="fH" placeholder="' + t().hotel_ph + '" value="' + esc(w.hotel) + '"></label>' +
      '</form>' +
      '<label class="bk-check"><input type="checkbox" checked> <span>' + t().terms + '</span></label>' +
      (w.err ? '<p class="bk-err">' + w.err + '</p>' : '') +
      '<div class="bk-actions"><button class="bk-btn ghost" data-act="s1">' + t().back + '</button><button class="bk-btn dark" data-act="s3">' + t().to_pay + '</button></div>';
  }

  function step3(o) {
    return stepsHtml() + '<div class="bk-hold">⏱ ' + t().hold + ' <span id="bkHold">' + holdLeft(o) + '</span></div>' +
      rows(o) + '<div class="bk-total"><span>' + t().total + '</span><b>$' + D.total(o) + '</b></div>' +
      '<button class="bk-btn full" data-act="pp" data-m="paypal">' + t().pay_pp + '</button>' +
      '<button class="bk-btn ghost full" data-act="pp" data-m="card">' + t().pay_card + '</button>' +
      '<p class="bk-note">' + t().card_note + '</p>' +
      '<div class="bk-actions"><button class="bk-btn ghost sm" data-act="back2">' + t().back + '</button></div>';
  }

  function step4(o) {
    return stepsHtml() + '<div class="bk-ok">' + t().paid + '</div>' +
      '<div class="bk-ticket"><h2>' + t().see_you(esc(o.name.split(' ')[0])) + '</h2>' +
      '<div class="bk-qr">' + D.qrSvg(o.code) + '</div><div class="bk-code">' + o.code + '</div>' +
      '<p class="bk-note">' + t().show_qr + '</p>' + rows(o, true) +
      '<p class="bk-note">' + t().sent(esc(o.email)) + '</p></div>' +
      '<div class="bk-admin"><strong>Demo pro tým · jen v prototypu</strong><p>Tahle vstupenka je teď v Totem Adminu. Otevři ji rovnou ve skeneru u vstupu a pusť hosty dovnitř.</p>' +
      '<div class="bk-actions"><a class="bk-btn dark sm" href="admin/#scan=' + o.code + '">Otevřít v adminu →</a><a class="bk-btn ghost sm" href="admin/#online">Online objednávky</a></div></div>' +
      '<div class="bk-actions"><button class="bk-btn ghost" data-act="new">' + t().new_b + '</button></div>';
  }

  function sideHtml() {
    var o = current() || w;
    var has = D.pax(o) > 0;
    return '<div class="bk-box"><h3>' + t().sum_title + '</h3>' +
      (has ? rows({ date: o.date, slot: free() ? null : (o.slot || w.slot), ad: o.ad, ch: o.ch, inf: o.inf }) + '<div class="bk-total"><span>' + t().total + '</span><b>$' + D.total(o) + '</b></div>' : '<p class="bk-note">' + t().select + '</p>') +
      '</div><div class="bk-box"><ul class="bk-incl">' + t().incl.map(function (x) { return '<li>' + x + '</li>'; }).join('') + '</ul></div>';
  }

  function render() {
    var o = current();
    if (w.step >= 3 && !o) w.step = 1;
    if (w.step === 1 && !free() && !w.slot) w.slot = D.SLOTS.filter(function (z) { return left(w.date, z) > 0; })[0] || null;
    root.innerHTML = w.step === 1 ? step1() : w.step === 2 ? step2() : w.step === 3 ? step3(o) : step4(o);
    side.innerHTML = sideHtml();
  }

  function keepForm() {
    var g = function (id) { return document.getElementById(id); };
    if (g('fN')) { w.name = g('fN').value; w.email = g('fE').value; w.phone = g('fP').value; w.hotel = g('fH').value; }
  }

  function ppModal(method) {
    var o = current(); if (!o) return;
    layer.innerHTML = '<div class="bk-modal" data-bg="1"><section class="bk-card" role="dialog" aria-modal="true" aria-label="' + t().pp_title + '">' +
      '<h3>' + t().pp_title + '</h3><p class="bk-note">' + t().pp_note + '</p>' +
      '<div class="bk-total"><span>' + (method === 'card' ? t().pay_card : 'PayPal') + '</span><b>$' + D.total(o) + '</b></div>' +
      '<button class="bk-btn full" data-act="ppPay">' + t().pp_pay + ' $' + D.total(o) + '</button>' +
      '<div class="bk-actions"><button class="bk-btn ghost sm" data-act="ppFail">' + t().pp_fail + '</button><button class="bk-btn ghost sm" data-act="ppClose">' + t().pp_close + '</button></div>' +
      '</section></div>';
  }

  document.addEventListener('click', function (e) {
    if (e.target.dataset && e.target.dataset.bg) { layer.innerHTML = ''; return; }
    var b = e.target.closest('button'); if (!b || !b.closest('#bk, #bkLayer')) return;
    var d = b.dataset; w.err = '';
    if (d.day) {
      w.date = d.day;
      if (!free() && left(w.date, w.slot) <= 0) w.slot = D.SLOTS.filter(function (z) { return left(w.date, z) > 0; })[0] || null;
      render(); return;
    }
    if (d.slot) { w.slot = d.slot; render(); return; }
    if (d.q) { var p = d.q.split(':'); w[p[0]] = Math.max(0, Math.min(20, w[p[0]] + Number(p[1]))); render(); return; }
    switch (d.act) {
      case 's1': keepForm(); w.step = 1; render(); break;
      case 's2': w.step = 2; render(); break;
      case 's3': {
        keepForm(); sync();
        if (!w.name.trim() || !/^\S+@\S+\.\S+$/.test(w.email.trim())) { w.err = t().err_form; render(); break; }
        var s = free() ? null : w.slot;
        if (D.pax(w) > left(w.date, s)) { w.step = 1; w.err = t().err_full; render(); break; }
        var code = D.newCode();
        orders.unshift({ code: code, name: w.name.trim(), email: w.email.trim(), phone: w.phone.trim(), hotel: w.hotel.trim(), lang: lang.toUpperCase(), date: w.date, slot: s, ad: w.ad, ch: w.ch, inf: w.inf, st: 'drzi', hold: Date.now() + 15 * 60000, at: D.TODAY, src: 'web' });
        D.save(orders); w.code = code; w.step = 3; render(); window.scrollTo(0, 0);
        break;
      }
      case 'back2': sync(); orders = orders.filter(function (o) { return o.code !== w.code; }); D.save(orders); w.code = null; w.step = 2; render(); break;
      case 'pp': ppModal(d.m); break;
      case 'ppPay': {
        sync(); var o = current(); layer.innerHTML = '';
        if (!o || o.st !== 'drzi') { w.step = 1; w.code = null; w.err = t().expired; render(); break; }
        o.st = 'zaplaceno'; delete o.hold; D.save(orders); w.step = 4; render(); window.scrollTo(0, 0);
        break;
      }
      case 'ppFail': layer.innerHTML = ''; toast(t().declined); break;
      case 'ppClose': layer.innerHTML = ''; break;
      case 'new': w = { step: 1, date: w.date, slot: w.slot || '13:00', ad: 2, ch: 0, inf: 0, name: w.name, email: w.email, phone: w.phone, hotel: w.hotel, code: null, err: '' }; render(); window.scrollTo(0, 0); break;
    }
  });

  document.addEventListener('submit', function (e) { if (e.target.id === 'bkForm') e.preventDefault(); });
  document.addEventListener('totem:lang', function (e) { keepForm(); lang = e.detail; render(); });
  window.addEventListener('storage', function (e) {
    if (e.key === D.K_ORDERS || e.key === D.K_SETTINGS) { keepForm(); sync(); if (w.step !== 2) render(); }
  });

  setInterval(function () {
    var o = current();
    if (w.step === 3 && o) {
      if (o.hold < Date.now()) { sync(); w.step = 1; w.code = null; w.err = t().expired; layer.innerHTML = ''; render(); return; }
      var el = document.getElementById('bkHold'); if (el) el.textContent = holdLeft(o);
    }
  }, 1000);

  sync();
  if (free()) w.slot = null;
  render();
})();
