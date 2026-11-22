BEGIN;
ALTER TABLE public.hood_bundle_items ADD COLUMN IF NOT EXISTS cover_path text;

CREATE OR REPLACE FUNCTION private.hood_save_bundle_with_photos(
 p_id uuid,p_name text,p_description text,p_price integer,p_products uuid[],
 p_status text,p_cover_paths text[]
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE bundle_id uuid;
BEGIN
 IF p_cover_paths IS NULL OR cardinality(p_cover_paths) IS DISTINCT FROM cardinality(p_products) THEN
  RAISE EXCEPTION 'Choose a cover photo or the default for each item';
 END IF;
 bundle_id:=private.hood_save_bundle(p_id,p_name,p_description,p_price,p_products,p_status);
 IF EXISTS(
  SELECT 1 FROM unnest(p_products,p_cover_paths) AS selected(product_id,path)
  JOIN public.products component ON component.id=selected.product_id
  JOIN public.categories category ON category.id=component.category_id
  WHERE selected.path IS NOT NULL AND NOT EXISTS(
   SELECT 1 FROM public.product_images image
   JOIN public.products source ON source.id=image.product_id
   WHERE image.path=selected.path AND source.storefront='hood'
    AND source.status='published' AND NOT source.enquiry_only AND NOT source.is_bundle
    AND (source.id=component.id OR (
     source.category_id=component.category_id AND category.storefront='hood'
     AND category.slug IN ('hood-plain-hoodies','hood-sweatshirts','hood-zipper-hoodies')
    ))
  )
 ) THEN
  RAISE EXCEPTION 'A selected cover photo is unavailable. Choose another photo.';
 END IF;
 UPDATE public.hood_bundle_items AS item
 SET cover_path=selected.path
 FROM unnest(p_products,p_cover_paths) AS selected(product_id,path)
 WHERE item.bundle_product_id=bundle_id AND item.product_id=selected.product_id;
 RETURN bundle_id;
END $$;
REVOKE ALL ON FUNCTION private.hood_save_bundle_with_photos(uuid,text,text,integer,uuid[],text,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.hood_save_bundle_with_photos(uuid,text,text,integer,uuid[],text,text[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.hood_save_bundle_with_photos(
 p_id uuid,p_name text,p_description text,p_price integer,p_products uuid[],
 p_status text,p_cover_paths text[]
)
RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$
 SELECT private.hood_save_bundle_with_photos($1,$2,$3,$4,$5,$6,$7)
$$;
REVOKE ALL ON FUNCTION public.hood_save_bundle_with_photos(uuid,text,text,integer,uuid[],text,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hood_save_bundle_with_photos(uuid,text,text,integer,uuid[],text,text[]) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
