# THE HOOD.PK

Run `npm start` inside the extracted `cloth-web` folder to serve the included build at http://localhost:4173. For source development, run `npm ci` followed by `npm run dev`.

## Account confirmation and customer care

Customers sign in by email and password. Use **Resend confirmation email** after registration or an unconfirmed sign-in. The frontend submits signup and resend requests to Supabase Auth. Live Gmail receipt depends on the deployed project's mail configuration. Verify the authorized site origin and callback redirect, sender configuration, and Auth mail delivery logs before release.

**Contact us on WhatsApp** opens the configured store number. Order help includes the order reference and product names when present. The 50% advance notice is shown during checkout, where the payment rule is applied.

## Unlimited availability

HoodPK sells active colour and size options without tracking stock. The update keeps existing colours and sizes and ignores legacy stock counts for active variants. The per-cart-line limit remains 99 units.

For a HoodPK database with the earlier bundle updates installed, apply `supabase/updates/hood_unlimited_availability.sql` before deploying this version. For a fresh setup, finish the bundle updates below first, then apply the unlimited-availability update.

## Bundle photos, prices and default colours

In **Admin → Bundles**, select your products and choose a cover photo under each item. Related products in the plain hoodie, sweatshirt and zipper categories can supply other colour photos for that slot. The saved photos appear on the bundle card and gallery. Customer choices come from the active colour and size options for each item.

The 12 default swatches use the first 12 colours in the packaged plain-hoodie palette. Existing product colours stay available, including any outside the default set. Assign optional colour photos in **Admin → Products → Photography**. A colour without a dedicated photo uses the main product photo.

For an existing HoodPK database that already supports bundles, apply `supabase/updates/hood_bundle_cover_photos.sql` before saving custom bundle photos. For a new setup, complete the base setup below, then apply `hood_customisation_notes.sql`, `hood_bundles.sql`, `hood_bundle_category_colours.sql`, and `hood_bundle_cover_photos.sql` from `supabase/updates/` in that order.

## Base backend setup

This package contains the fully prepared frontend/backend connection, but it is NOT activated on the live project yet. Read BACKEND_APPROVAL.md before deployment.

The one complete database update is RUN_BACKEND_SETUP.sql (also in supabase/updates/hood_backend_complete.sql). It replaces the older base activation scripts. The bundle updates listed above are separate.

After the full SQL update is approved and applied to cloth-web, deploy the two new Edge Functions: hood-instagram-feed and hood-new-arrival-emails. Their source is in supabase/functions. The existing other-storefront endpoints are preserved.

The frontend now reads HOOD products/categories from Supabase and uses HOOD-specific cart, checkout, admin-save and payment RPCs. Do not deploy this new frontend before the complete database upgrade: the required HOOD tables/RPCs do not exist yet.

Local commands: npm ci; npm test; npm run build; npm run dev.

Current catalogue: 10 enquiry listings, 23 supplied photos, 14 hoodie colours, WhatsApp +92 309 8670057. No product price, size or stock was invented. No fictional reviews are displayed.
