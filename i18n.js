(function () {
  var T = {
    es: {
      title: 'Totem Nature Park — Uvero Alto, República Dominicana',
      description: 'Excursión de 3,5 horas de fauna y cultura taína con contacto directo, a quince minutos de Uvero Alto. Alimentación y traslado al hotel incluidos.',
      nav_aviary: 'Aviario', nav_vivarium: 'Vivarium', nav_garden: 'Jardín', nav_visit: 'Visítanos', nav_tickets: 'Entradas',
      hero_alt: 'Selva tropical del parque — guacamaya, mono ardilla, perezoso y caimán',
      hero_eyebrow: 'Secretos de la naturaleza · N.º 01',
      hero_text: 'Excursión de 3,5 horas de fauna y cultura taína con contacto directo: tocas y alimentas a los animales y visitas una aldea taína viva, a quince minutos de Uvero Alto.',
      badge_contact: 'Experiencia de contacto', badge_feeding: 'Alimentación incluida', badge_opening: 'Apertura 15 nov 2026',
      cta_tickets: 'Entradas', cta_getting: 'Cómo llegar',
      stat_1: 'Desde Uvero Alto', stat_2_num: '3,5 h', stat_2: 'De programa', stat_3: 'Estaciones guiadas', stat_4: 'Visitantes por grupo',
      zones_eyebrow: 'Explora el parque',
      zones_title: 'Sin cristales<br>de por medio',
      zones_lead: 'Cada visitante va a su ritmo. Un cuidador atiende cada exhibición y responde preguntas; dos momentos tienen horario anunciado. Aquí los animales se tocan y se alimentan junto a un cuidador, y la alimentación está incluida.',
      card1_alt: 'Tucán y colibrí en el Aviario', card1_title: 'Aviario',
      card1_text: 'Guacamayos y loros de cerca: contacto y foto con las aves, acompañado por un cuidador.',
      card2_alt: 'Iguana y serpiente en el Vivarium',
      card2_text: 'Iguanas rinoceronte para tocar, reptiles y serpientes para la foto, y la alimentación del cocodrilo americano a hora anunciada.',
      card3_alt: 'Orquídeas del jardín botánico', card3_title: 'Perezosos, monos y aldea taína',
      card3_text: 'Perezosos para tocar, monos ardilla con entrada guiada y una aldea taína viva con programa cultural de 45 minutos.',
      more: 'Ver más →',
      tickets_eyebrow: 'Por persona · USD · traslado al hotel incluido',
      tickets_title: 'Entradas',
      tickets_text: 'Un único precio fijo, con recogida y regreso al hotel. La alimentación de los animales está incluida.',
      price_adult: 'Adulto', price_child: 'Niño 3–12',
      tickets_fine: 'Fotos, bebidas y souvenirs se venden en el parque. Condiciones de cancelación por escrito y certificado de seguro a solicitud.',
      book: 'Reservar por WhatsApp',
      visit_eyebrow: 'Planifica tu visita', visit_title: 'Cómo llegar',
      fact_address: 'Uvero Alto, La Altagracia, República Dominicana — a 15 minutos de los resorts de Uvero Alto',
      fact_departures: 'Salidas de mañana y tarde, con recogida en tu hotel de Uvero Alto',
      fact_booking: 'Reservas por WhatsApp o correo, confirmadas el mismo día',
      map_alt: 'Mapa del parque con zonas y fauna',
      footer_copy: '© 2026 Totem Nature Park · Uvero Alto, La Altagracia, República Dominicana'
    },
    en: {
      title: 'Totem Nature Park — Uvero Alto, Dominican Republic',
      description: 'A hands-on, 3.5-hour wildlife and Taíno culture excursion, fifteen minutes from Uvero Alto. Feeding and hotel transfer included.',
      nav_aviary: 'Aviary', nav_vivarium: 'Vivarium', nav_garden: 'Garden', nav_visit: 'Visit us', nav_tickets: 'Tickets',
      hero_alt: 'Tropical rainforest of the park — macaw, squirrel monkey, sloth and caiman',
      hero_eyebrow: 'Secrets of Nature · No. 01',
      hero_text: 'A hands-on, 3.5-hour wildlife and Taíno culture excursion: touch and feed the animals and visit a living Taíno village, fifteen minutes from Uvero Alto.',
      badge_contact: 'Contact experience', badge_feeding: 'Feeding included', badge_opening: 'Opening 15 Nov 2026',
      cta_tickets: 'Tickets', cta_getting: 'Getting here',
      stat_1: 'From Uvero Alto', stat_2_num: '3.5 h', stat_2: 'Programme', stat_3: 'Hosted stations', stat_4: 'Guests per wave',
      zones_eyebrow: 'Explore the park',
      zones_title: 'Not behind<br>glass',
      zones_lead: 'Guests move at their own pace. A keeper hosts every exhibit, explains and answers questions; two moments run on announced times. Here you touch and feed the animals alongside a keeper, and feeding is included.',
      card1_alt: 'Toucan and hummingbird in the Aviary', card1_title: 'Aviary',
      card1_text: 'Macaws and parrots up close: contact and photo with the birds, accompanied by a keeper.',
      card2_alt: 'Iguana and snake in the Vivarium',
      card2_text: 'Rhinoceros iguanas to touch, reptiles and snakes for photos, and the American crocodile fed at an announced time.',
      card3_alt: 'Orchids in the botanical garden', card3_title: 'Sloths, monkeys and Taíno village',
      card3_text: 'Sloths to touch, squirrel monkeys with a hosted entry and a living Taíno village with a 45-minute cultural programme.',
      more: 'See more →',
      tickets_eyebrow: 'Per person · USD · hotel transfer included',
      tickets_title: 'Tickets',
      tickets_text: 'One fixed price, including hotel pick-up and return. Feeding the animals is included.',
      price_adult: 'Adult', price_child: 'Child 3–12',
      tickets_fine: 'Photos, drinks and souvenirs are sold on site. Written cancellation terms and insurance certificate on request.',
      book: 'Book on WhatsApp',
      visit_eyebrow: 'Plan your visit', visit_title: 'Getting here',
      fact_address: 'Uvero Alto, La Altagracia, Dominican Republic — 15 minutes from the Uvero Alto resorts',
      fact_departures: 'Morning and afternoon departures, with pick-up at your Uvero Alto hotel',
      fact_booking: 'Booking by WhatsApp or e-mail, confirmed the same day',
      map_alt: 'Park map with zones and wildlife',
      footer_copy: '© 2026 Totem Nature Park · Uvero Alto, La Altagracia, Dominican Republic'
    }
  };

  var KEY = 'totem-lang';

  function initial() {
    try {
      var saved = localStorage.getItem(KEY);
      if (saved && T[saved]) return saved;
    } catch (e) {}
    return (navigator.language || 'es').toLowerCase().indexOf('en') === 0 ? 'en' : 'es';
  }

  function apply(lang) {
    var d = T[lang];
    document.documentElement.lang = lang;
    document.title = d.title;
    var meta = document.querySelector('meta[name="description"]');
    if (meta) meta.setAttribute('content', d.description);

    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      var v = d[el.getAttribute('data-i18n')];
      if (v !== undefined) el.innerHTML = v;
    });
    document.querySelectorAll('[data-i18n-alt]').forEach(function (el) {
      var v = d[el.getAttribute('data-i18n-alt')];
      if (v !== undefined) el.setAttribute('alt', v);
    });
    document.querySelectorAll('.lang-btn').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.getAttribute('data-lang') === lang));
    });
    try { localStorage.setItem(KEY, lang); } catch (e) {}
  }

  document.querySelectorAll('.lang-btn').forEach(function (b) {
    b.addEventListener('click', function () { apply(b.getAttribute('data-lang')); });
  });

  apply(initial());
})();
