# webput

Upload a page to Cloudflare Pages. The path is the identity.

```sh
nix run github:srid/webput -- login
nix run github:srid/webput -- publish foo.html
# -> https://foo.pages.dev

nix run github:srid/webput -- publish foo.pages.dev
# -> https://foo.pages.dev
```

A file is published as `index.html`. A directory must be named `<name>.pages.dev` and contain `index.html` (plus any assets). Same command updates.

`login` uses the device-code flow (works on SSH/headless): prints a URL and a short code — open the URL on any phone or laptop. OAuth is stored in `~/.config/webput/.wrangler/`, not the global Wrangler login. Or set `CLOUDFLARE_API_TOKEN`.

MIT.
