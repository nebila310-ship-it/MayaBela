# smartschool.majobridge.com

Public marketing and demo-request site for **Majo Bridge OS**. It does **not** replace the Flutter school app.

- Product / login: `https://www.majobridge.com`
- This site: `https://smartschool.majobridge.com`
- Demo and pricing CTAs open WhatsApp `+251 912 798 279`

## Local preview

```bash
python3 -m http.server 4173 --bind 127.0.0.1 --directory site
```

## Deploy (separate Cloudflare Pages project)

Do **not** deploy this folder as `mayabela`. Create a new Pages project, for example `majobridge-smartschool`, then:

```bash
npx wrangler@4 pages deploy site --project-name=majobridge-smartschool --commit-dirty=true
```

DNS at the registrar for `majobridge.com`:

- `smartschool` CNAME → the Pages hostname for that project
- Keep `www` pointed at the live product
- Reserve `www`, `smartschool`, `app`, `api`, `mail`, `admin`, `platform` so they are never used as a school slug
