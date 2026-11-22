# Colour selection and optional photos

- New products start with the store's saved Plain Hoodies colour palette selected. The current saved catalogue may have more than twelve colours; untick any colours you do not offer.
- In admin, use Select all store colours for an existing product. Choose sizes and stock, then Add store colours & sizes. Existing combinations retain their inventory; newly added combinations use the entered stock (zero by default).
- Each photo has an optional colour dropdown. Matching colour photos appear first when the customer chooses that colour.
- Without a matching photo, the original cover remains visible. The chosen colour is preserved, and the product page identifies the photo as a reference.
- Stock and customer order colour continue to use the existing validated product variants and checkout flow. No live products or inventory were changed by this code update.
- All 71 tests passed, including missing-colour-photo fallback and preserving existing stock. Production build passed.
