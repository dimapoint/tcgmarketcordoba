# Riot Developer Portal — Application draft

Texto para el formulario de registro de la app (en inglés). Ajustar la URL
si el nombre `tcgmarketcordoba` no está libre en Fly.

---

**App name:** TCG Market Córdoba

**App URL:** https://tcgmarketcordoba.fly.dev

**Platforms:** Web (responsive, works on desktop and mobile browsers). Native Android and iOS builds are planned from the same Flutter codebase.

**Distribution:** Publicly accessible web app at the URL above. Future mobile builds would be distributed through Google Play and the App Store.

## Description / use case

TCG Market Córdoba is a free, community-oriented card library and local
peer-to-peer marketplace for **physical** Riftbound cards, focused on the
player community of Córdoba, Argentina.

Local players currently buy, sell and trade their physical cards through
unstructured Facebook/WhatsApp groups, where listings are hard to search
and card identification is error-prone (wrong set, wrong printing, no
images). TCG Market Córdoba solves this with a searchable catalog of
Riftbound cards and structured listings tied to exact printings.

**How the Riftbound API delivers on this use case:** the app uses
`riftbound-content-v1` exclusively as its card reference library. Card
names, sets, collector numbers, rarities, domains, stats and official card
art let sellers pick the exact printing they are listing and let buyers
see accurate, official card information instead of blurry photos and
free-text descriptions. Content is synced server-side into our database
(a single request per sync, run manually when a new set releases), so the
app makes no per-user calls to Riot's API.

## User flow

1. A player signs up with email and sets up a profile (city + contact
   methods: WhatsApp, Instagram or Telegram).
2. **Browse:** the home screen shows active listings from local players —
   official card image, set and collector number, condition, price in ARS
   and the seller's city. Listings can be searched and filtered.
3. **Publish:** the seller types a card name, the app searches the synced
   Riftbound catalog and shows matching printings (set, collector number,
   normal/foil, official art). The seller picks the exact printing, sets
   condition and price, optionally adds photos of the physical copy, and
   publishes.
4. **Contact:** an interested buyer opens the listing and reaches the
   seller through their published contact method to arrange an in-person
   meetup in Córdoba. The app itself handles no payments and no shipping —
   it only connects local players.

## Policy compliance

- The app is a card library + marketplace facilitator for physical cards:
  no digital gameplay, no automated rule enforcement, no standalone client.
- No matchmaking, ranks or ladders; no metagame statistics are collected
  or published.
- No blockchain, crypto or gambling of any kind.
- Free to use; no unfair monetization (no paywalled Riot content).
- Riot IP is used only as provided by the official API, with attribution;
  the app is clearly identified as an unofficial fan project per Riot's
  "Legal Jibber Jabber" guidelines.
