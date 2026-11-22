# Publish HoodPK on hoodpk.com

## Netlify

1. Extract the ZIP. For a manual deploy, upload the `cloth-web/dist` folder in Netlify. It already contains the production build and `_redirects`. For a source-based deploy, use `cloth-web` as the project root and let `netlify.toml` build and publish `dist`.
2. In the correct Netlify site's domain settings, add `hoodpk.com` and `www.hoodpk.com` and set `hoodpk.com` as the primary domain. Apply the DNS records Netlify displays at the domain registrar and wait until HTTPS is active for both names. Netlify should serve client routes through the included rewrite and send www requests to the primary domain.
3. If you already deploy both store apps from a shared backend, keep this frontend on its own hosting site. Use the installed HoodPK database migrations as described in START_HERE.md.

## Supabase Auth

Open Authentication → URL Configuration in the `cloth-web` project (`oapkgdvsnpakpackmgcs`). Add these two HoodPK entries under **Redirect URLs**:

- `https://hoodpk.com/auth/callback**` — supports the optional `returnTo` query parameter.
- `https://hoodpk.com/reset-password`

Set **Site URL** to `https://hoodpk.com` if HoodPK owns the project's default fallback. If another store relies on that setting, keep its existing Site URL and add the HoodPK redirect entries above. The HoodPK frontend sends the explicit production URL with each request. For shared email templates, keep the standard `{{ .ConfirmationURL }}` action link so Supabase uses each app's approved redirect. Replace any hard-coded localhost URL in the email action link.

Once DNS, HTTPS and the allowlist are active, request a fresh confirmation or password-reset email. Previously sent links may still contain their original redirect. To test confirmation, use a genuinely new email address. To test recovery, use an existing test account. Open the fresh link from another browser or phone and verify the domain and destination.

For HoodPK newsletter links, set the Hood-specific `HOOD_SITE_URL` Edge Function secret to `https://hoodpk.com` if that function is used.
