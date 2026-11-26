# Totem Nature Park

Statický web (HTML + CSS) pro Totem Nature Park, Punta Cana — směr "Expedition Poster" (Alfa Slab One + Barlow, paleta oxblood / gold / palm / bone).

- `index.html` – stránka
- `styles.css` – styly
- `assets/` – fotografie

Lokálně stačí otevřít `index.html` v prohlížeči. Publikace přes GitHub Pages (Settings → Pages → branch `main`, složka `/ (root)`).

## Totem Admin: jazyky

Admin (`admin/`) je ve čtyřech jazycích: CZ, SK, EN a ES. Přepínač je v levém menu, volba se pamatuje v prohlížeči a napoprvé se vezme jazyk prohlížeče. Web pro hosty zůstává jen ES a EN.

- Admin se píše česky, překlady jsou v `admin/i18n.js` (řádek = čeština, slovenština, angličtina, španělština). Nový text v Adminu = nový řádek ve slovníku, jinak zůstane česky.
- `admin/i18n-engine.js` překládá vykreslené texty rozhraní. Data, která lidé zadají (názvy položek, úkoly, poznámky), se nepřekládají.
