BEGIN;

CREATE OR REPLACE FUNCTION private.hood_change_cart(p_variant_id uuid, p_quantity integer, p_operation text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  uid uuid := auth.uid();
  current_quantity integer;
  desired integer;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  INSERT INTO public.carts(user_id) VALUES(uid) ON CONFLICT DO NOTHING;
  PERFORM 1 FROM public.carts c WHERE c.user_id=uid FOR UPDATE;
  IF NOT EXISTS (
    SELECT 1 FROM public.product_variants v JOIN public.products p ON p.id=v.product_id
    WHERE v.id=p_variant_id AND p.storefront='hood'
  ) THEN RAISE EXCEPTION 'HOOD product not found'; END IF;
  IF p_operation='remove' THEN
    DELETE FROM public.cart_items ci WHERE ci.user_id=uid AND ci.variant_id=p_variant_id;
    RETURN;
  END IF;
  IF p_operation IS NULL OR p_operation NOT IN ('add','set') OR p_quantity IS NULL OR p_quantity<1 OR p_quantity>99 THEN
    RAISE EXCEPTION 'Quantity must be between 1 and 99' USING ERRCODE='22023';
  END IF;
  PERFORM 1 FROM public.product_variants pv
  JOIN public.products p ON p.id=pv.product_id
  WHERE pv.id=p_variant_id AND pv.active AND p.storefront='hood' AND NOT p.enquiry_only AND p.status='published' FOR SHARE OF p,pv;
  IF NOT FOUND THEN RAISE EXCEPTION 'This product is no longer available'; END IF;
  SELECT ci.quantity INTO current_quantity FROM public.cart_items ci WHERE ci.user_id=uid AND ci.variant_id=p_variant_id;
  IF p_operation='set' AND NOT FOUND THEN RAISE EXCEPTION 'Cart item not found'; END IF;
  desired := CASE WHEN p_operation='add' THEN coalesce(current_quantity,0)+p_quantity ELSE p_quantity END;
  IF desired>99 THEN RAISE EXCEPTION 'Quantity must be between 1 and 99' USING ERRCODE='22023'; END IF;
  INSERT INTO public.cart_items(user_id,variant_id,quantity) VALUES(uid,p_variant_id,desired)
  ON CONFLICT(user_id,variant_id) DO UPDATE SET quantity=excluded.quantity;
END $function$
;

CREATE OR REPLACE FUNCTION private.hood_checkout_impl(p_shipping jsonb, p_shipping_cents integer, p_request_id uuid)
 RETURNS TABLE(order_id uuid, order_number bigint, total_cents bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  uid uuid := auth.uid();
  new_order_id uuid;
  new_order_number bigint;
  subtotal bigint;
  address jsonb;
  item record;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'Checkout request ID is required' USING ERRCODE='22023'; END IF;
  IF coalesce(p_shipping_cents,0) NOT IN (0,30000) THEN RAISE EXCEPTION 'Delivery is fixed at Rs. 300' USING ERRCODE='22023'; END IF;
  INSERT INTO public.carts(user_id) VALUES(uid) ON CONFLICT DO NOTHING;
  -- The same cart lock is taken by all three cart mutations.
  PERFORM 1 FROM public.carts c WHERE c.user_id=uid FOR UPDATE;
  RETURN QUERY SELECT o.id,o.order_number,o.total_cents FROM public.orders o WHERE o.user_id=uid AND o.request_id=p_request_id AND o.storefront='hood';
  IF FOUND THEN RETURN; END IF;

  IF p_shipping IS NULL OR jsonb_typeof(p_shipping)<>'object' THEN RAISE EXCEPTION 'Enter a shipping address'; END IF;
  IF length(btrim(coalesce(p_shipping->>'full_name',''))) NOT BETWEEN 1 AND 150
     OR length(btrim(coalesce(p_shipping->>'line1',''))) NOT BETWEEN 1 AND 300
     OR length(btrim(coalesce(p_shipping->>'city',''))) NOT BETWEEN 1 AND 150
     OR length(btrim(coalesce(p_shipping->>'country',''))) NOT BETWEEN 1 AND 100
     OR length(coalesce(p_shipping->>'postal_code',''))>20 OR length(coalesce(p_shipping->>'phone',''))>30 THEN
    RAISE EXCEPTION 'Enter a valid name, street address, city and country' USING ERRCODE='22023';
  END IF;
  IF lower(btrim(p_shipping->>'country')) NOT IN ('pakistan','pk') THEN RAISE EXCEPTION 'Delivery is available within Pakistan only';END IF;
  IF regexp_replace(coalesce(p_shipping->>'phone',''),'[ ()-]','','g') !~ '^\+?[0-9]{10,15}$' THEN RAISE EXCEPTION 'Enter a valid contact number';END IF;
  address:=jsonb_build_object('full_name',btrim(p_shipping->>'full_name'),'line1',btrim(p_shipping->>'line1'),
    'city',btrim(p_shipping->>'city'),'country',btrim(p_shipping->>'country'),
    'postal_code',btrim(coalesce(p_shipping->>'postal_code','')),'phone',btrim(coalesce(p_shipping->>'phone','')));
  IF NOT EXISTS(SELECT 1 FROM public.cart_items ci JOIN public.product_variants v ON v.id=ci.variant_id JOIN public.products p ON p.id=v.product_id WHERE ci.user_id=uid AND p.storefront='hood') THEN RAISE EXCEPTION 'Your bag is empty'; END IF;
  -- Freeze prices/publication state, then lock variant choices in a consistent order.
  PERFORM p.id FROM public.products p WHERE p.id IN (
    SELECT pv.product_id FROM public.product_variants pv JOIN public.cart_items ci ON ci.variant_id=pv.id WHERE ci.user_id=uid
    UNION SELECT (x->>'product_id')::uuid FROM public.cart_items ci CROSS JOIN LATERAL jsonb_array_elements(ci.bundle_selection)x WHERE ci.user_id=uid
  ) AND p.storefront='hood' ORDER BY p.id FOR SHARE;
  PERFORM pv.id FROM public.product_variants pv WHERE pv.id IN (
    SELECT ci.variant_id FROM public.cart_items ci WHERE ci.user_id=uid
    UNION SELECT (x->>'variant_id')::uuid FROM public.cart_items ci CROSS JOIN LATERAL jsonb_array_elements(ci.bundle_selection)x WHERE ci.user_id=uid
  ) ORDER BY pv.id FOR UPDATE;
  FOR item IN SELECT pv.active,p.status,p.enquiry_only,p.effective_price_cents FROM public.cart_items ci
    JOIN public.product_variants pv ON pv.id=ci.variant_id JOIN public.products p ON p.id=pv.product_id WHERE ci.user_id=uid AND p.storefront='hood'
  LOOP
    IF item.enquiry_only OR item.effective_price_cents IS NULL THEN RAISE EXCEPTION 'Enquiry products cannot be checked out';END IF;
    IF NOT item.active OR item.status<>'published' THEN RAISE EXCEPTION 'A piece in your bag is no longer available'; END IF;
  END LOOP;
  SELECT sum(p.effective_price_cents::bigint*ci.quantity) INTO subtotal FROM public.cart_items ci
  JOIN public.product_variants pv ON pv.id=ci.variant_id JOIN public.products p ON p.id=pv.product_id WHERE ci.user_id=uid AND p.storefront='hood';
  INSERT INTO public.orders AS o(user_id,request_id,status,payment_status,subtotal_cents,shipping_cents,total_cents,shipping_address,currency,storefront)
  VALUES(uid,p_request_id,'pending','unpaid',subtotal,30000,subtotal+30000,address,'PKR','hood')
  RETURNING o.id,o.order_number INTO new_order_id,new_order_number;
  INSERT INTO public.order_items(order_id,variant_id,product_name,color,size,image_path,unit_price_cents,quantity)
  SELECT new_order_id,pv.id,p.name,pv.color,pv.size,
    (SELECT im.path FROM public.product_images im WHERE im.product_id=p.id ORDER BY (lower(im.color)=lower(pv.color)) DESC NULLS LAST,im.position LIMIT 1),
    p.effective_price_cents,ci.quantity FROM public.cart_items ci JOIN public.product_variants pv ON pv.id=ci.variant_id
    JOIN public.products p ON p.id=pv.product_id WHERE ci.user_id=uid AND p.storefront='hood';
  INSERT INTO public.order_status_history(order_id,status) VALUES(new_order_id,'pending');
  DELETE FROM public.cart_items ci WHERE ci.user_id=uid AND EXISTS(SELECT 1 FROM public.product_variants v JOIN public.products p ON p.id=v.product_id WHERE v.id=ci.variant_id AND p.storefront='hood');
  RETURN QUERY SELECT new_order_id,new_order_number,subtotal+30000;
END $function$
;

CREATE OR REPLACE FUNCTION private.hood_update_order_status(p_order_id uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare current_status text;method text;payment text;
begin
 if auth.uid() is null or not private.is_admin() then raise exception 'Admin access required' using errcode='42501';end if;
 if p_status is null or p_status not in ('pending','confirmed','processing','shipped','delivered','cancelled') then raise exception 'Invalid status';end if;
 select o.status,o.payment_method,o.payment_status into current_status,method,payment from public.orders o where o.id=p_order_id and o.storefront='hood' for update;
 if not found then raise exception 'Order not found';end if;
 if current_status=p_status then return;end if;
 if current_status in ('cancelled','delivered') then raise exception 'This order is already closed';end if;
 if method='bank_transfer' and p_status in ('confirmed','processing','shipped','delivered') and payment<>'paid' and not exists(select 1 from public.orders o join public.payment_submissions ps on ps.order_id=o.id where o.id=p_order_id and ps.status='approved' and o.expected_advance_cents>0 and o.advance_paid_cents>=o.expected_advance_cents) then raise exception 'Verify and approve the payment in Payments before confirming this order';end if;
 if p_status='cancelled' then
  if current_status='shipped' then raise exception 'A shipped order cannot be cancelled; contact the customer about a return';end if;
  perform pv.id from public.product_variants pv where pv.id in(select oi.variant_id from public.order_items oi where oi.order_id=p_order_id) order by pv.id for update;
 elsif array_position(array['pending','confirmed','processing','shipped','delivered'],p_status)<=array_position(array['pending','confirmed','processing','shipped','delivered'],current_status) then raise exception 'Order status can only move forward';end if;
 update public.orders o set status=p_status where o.id=p_order_id;
 insert into public.order_status_history(order_id,status) values(p_order_id,p_status);
end $function$
;

CREATE OR REPLACE FUNCTION private.hood_snapshot_bundle()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE uid uuid; store text; pid uuid; ci public.cart_items;
BEGIN
 SELECT user_id,storefront INTO uid,store FROM public.orders WHERE id=NEW.order_id;
 IF store<>'hood' THEN RETURN NEW;END IF;
 SELECT product_id INTO pid FROM public.product_variants WHERE id=NEW.variant_id;
 IF NOT coalesce((SELECT is_bundle FROM public.products WHERE id=pid),false) THEN RETURN NEW;END IF;
 SELECT * INTO ci FROM public.cart_items WHERE user_id=uid AND variant_id=NEW.variant_id;
 IF ci.bundle_version IS DISTINCT FROM (SELECT bundle_version FROM public.products WHERE id=pid) THEN RAISE EXCEPTION 'Bundle has changed. Select its items again';END IF;
 NEW.bundle_selection:=private.hood_validate_bundle(pid,ci.bundle_selection,NEW.quantity);
 RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION private.hood_validate_bundle(pid uuid, selection jsonb, qty integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE result jsonb; expected integer;
BEGIN
 IF qty IS NULL OR qty NOT BETWEEN 1 AND 99 OR jsonb_typeof(selection)<>'array' THEN RAISE EXCEPTION 'Choose valid bundle options and quantity';END IF;
 SELECT count(*) INTO expected FROM public.hood_bundle_items WHERE bundle_product_id=pid;
 IF expected<2 OR jsonb_array_length(selection)<>expected THEN RAISE EXCEPTION 'Choose a colour and size for every bundle item';END IF;
 IF (SELECT count(DISTINCT coalesce(x->>'slot_product_id',x->>'product_id')) FROM jsonb_array_elements(selection)x)<>expected THEN RAISE EXCEPTION 'Choose each bundle slot once';END IF;
 SELECT jsonb_agg(jsonb_build_object('slot_product_id',b.product_id,'product_id',p.id,'variant_id',v.id,'product_name',p.name,'color',v.color,'size',v.size,'image_path',(SELECT im.path FROM public.product_images im WHERE im.product_id=p.id ORDER BY (im.color=v.color) DESC NULLS LAST,im.position LIMIT 1)) ORDER BY b.position)
 INTO result FROM public.hood_bundle_items b JOIN public.products seed ON seed.id=b.product_id JOIN public.categories category ON category.id=seed.category_id
 JOIN jsonb_array_elements(selection)x ON coalesce(x->>'slot_product_id',x->>'product_id')::uuid=b.product_id
 JOIN public.products p ON p.id=(x->>'product_id')::uuid
 JOIN public.product_variants v ON v.id=(x->>'variant_id')::uuid AND v.product_id=p.id
 WHERE b.bundle_product_id=pid AND p.storefront='hood' AND seed.storefront='hood' AND p.status='published' AND NOT p.enquiry_only AND NOT p.is_bundle AND v.active
 AND (p.id=seed.id OR (p.category_id=seed.category_id AND category.storefront='hood' AND category.slug IN('hood-plain-hoodies','hood-sweatshirts','hood-zipper-hoodies')));
 IF coalesce(jsonb_array_length(result),0)<>expected THEN RAISE EXCEPTION 'A bundle option is unavailable. Choose an available colour and size from the correct category';END IF;
 RETURN result;
END $function$
;

CREATE OR REPLACE FUNCTION private.hood_save_bundle(p_id uuid, p_name text, p_description text, p_price integer, p_products uuid[], p_status text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE pid uuid:=coalesce(p_id,gen_random_uuid());cid uuid; n integer;
BEGIN
 IF NOT private.is_admin() THEN RAISE EXCEPTION 'Admin access required';END IF;
 IF length(trim(p_name)) NOT BETWEEN 1 AND 200 OR length(coalesce(p_description,''))>8000 OR p_price IS NULL OR p_price<=0 OR p_price>100000000 OR p_status NOT IN ('draft','published','archived') THEN RAISE EXCEPTION 'Enter a name, valid fixed price and status';END IF;
 SELECT count(DISTINCT x) INTO n FROM unnest(p_products)x;
 IF n<2 OR n<>cardinality(p_products) THEN RAISE EXCEPTION 'Select at least two different products';END IF;
 IF (SELECT count(*) FROM public.products WHERE id=ANY(p_products) AND storefront='hood' AND NOT is_bundle AND NOT enquiry_only AND status='published')<>n THEN RAISE EXCEPTION 'Choose published, priced products; bundles cannot contain other bundles';END IF;
 IF EXISTS(SELECT 1 FROM unnest(p_products)x WHERE NOT EXISTS(SELECT 1 FROM public.product_variants WHERE product_id=x AND active)) THEN RAISE EXCEPTION 'Every included product needs at least one active colour and size option';END IF;
 SELECT id INTO cid FROM public.categories WHERE storefront='hood' AND slug='hood-combo-deals-bundles';
 IF cid IS NULL THEN RAISE EXCEPTION 'Combo category is missing';END IF;
 IF p_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.products WHERE id=pid AND storefront='hood' AND is_bundle) THEN RAISE EXCEPTION 'Bundle not found';END IF;
 INSERT INTO public.products(id,category_id,name,description,price_cents,status,featured,department,storefront,currency,enquiry_only,is_bundle)
 VALUES(pid,cid,trim(p_name),coalesce(p_description,''),p_price,p_status,false,'unisex','hood','PKR',false,true)
 ON CONFLICT(id) DO UPDATE SET name=excluded.name,description=excluded.description,price_cents=excluded.price_cents,sale_price_cents=null,status=excluded.status,bundle_version=public.products.bundle_version+1;
 DELETE FROM public.hood_bundle_items WHERE bundle_product_id=pid;
 INSERT INTO public.hood_bundle_items SELECT pid,x,ord::integer FROM unnest(p_products) WITH ORDINALITY t(x,ord);
 INSERT INTO public.product_variants(product_id,color,color_hex,size,active) VALUES(pid,'Choose each item','#111111','Bundle',true) ON CONFLICT(product_id,color,size) DO UPDATE SET active=true;
 RETURN pid;
END $function$
;

CREATE OR REPLACE FUNCTION private.hood_save_product(payload jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE pid uuid:=(payload->>'id')::uuid;cat uuid:=(payload->>'category_id')::uuid;inquiry boolean:=coalesce((payload->>'enquiry_only')::boolean,false);price integer; sale integer;entry jsonb;vid uuid;ids uuid[]:='{}';image_path_value text;counted integer;
BEGIN
 IF auth.uid() IS NULL OR NOT private.is_admin() THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';END IF;
 IF pid IS NULL OR length(btrim(coalesce(payload->>'name',''))) NOT BETWEEN 1 AND 200 THEN RAISE EXCEPTION 'Enter a product name';END IF;
 IF EXISTS(SELECT 1 FROM public.products p WHERE p.id=pid AND p.storefront<>'hood') THEN RAISE EXCEPTION 'This product belongs to another storefront';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.categories c WHERE c.id=cat AND c.storefront='hood') THEN RAISE EXCEPTION 'Choose a HOOD category';END IF;
 IF payload->>'status' NOT IN ('draft','published','archived') THEN RAISE EXCEPTION 'Invalid product status';END IF;
 IF jsonb_typeof(payload->'variants') IS DISTINCT FROM 'array' OR jsonb_typeof(payload->'images') IS DISTINCT FROM 'array' OR jsonb_array_length(payload->'images')>30 OR jsonb_array_length(payload->'variants')>500 THEN RAISE EXCEPTION 'Invalid product media or variants';END IF;
 IF inquiry THEN price:=NULL;sale:=NULL;
 ELSE
  price:=(payload->>'price_cents')::integer;sale:=nullif(payload->>'sale_price_cents','')::integer;
  IF price IS NULL OR price<=0 OR price>100000000 OR (sale IS NOT NULL AND (sale<=0 OR sale>=price)) THEN RAISE EXCEPTION 'Enter a valid product price';END IF;
  IF payload->>'status'='published' AND jsonb_array_length(payload->'variants')=0 THEN RAISE EXCEPTION 'Add at least one colour and size option before publishing';END IF;
 END IF;
 IF payload->>'status'='published' AND (length(btrim(coalesce(payload->>'description','')))=0 OR jsonb_array_length(payload->'images')=0) THEN RAISE EXCEPTION 'Add a description and photograph before publishing';END IF;
 IF jsonb_typeof(coalesce(payload->'inquiry_colours','[]'::jsonb)) IS DISTINCT FROM 'array' OR jsonb_array_length(coalesce(payload->'inquiry_colours','[]'::jsonb))>100 THEN RAISE EXCEPTION 'Invalid enquiry colours';END IF;
 INSERT INTO public.products(id,category_id,name,description,care,price_cents,sale_price_cents,status,featured,department,storefront,currency,enquiry_only,inquiry_colours,ingredients,new_arrival)
 VALUES(pid,cat,btrim(payload->>'name'),coalesce(payload->>'description',''),coalesce(payload->>'care',''),price,sale,payload->>'status',coalesce((payload->>'featured')::boolean,false),coalesce(payload->>'department','unisex'),'hood','PKR',inquiry,coalesce(payload->'inquiry_colours','[]'::jsonb),coalesce(payload->>'ingredients',''),coalesce((payload->>'new_arrival')::boolean,false))
 ON CONFLICT(id) DO UPDATE SET category_id=excluded.category_id,name=excluded.name,description=excluded.description,care=excluded.care,price_cents=excluded.price_cents,sale_price_cents=excluded.sale_price_cents,status=excluded.status,featured=excluded.featured,department=excluded.department,enquiry_only=excluded.enquiry_only,inquiry_colours=excluded.inquiry_colours,ingredients=excluded.ingredients,new_arrival=excluded.new_arrival;
 FOR entry IN SELECT * FROM jsonb_array_elements(payload->'variants') LOOP
  IF length(btrim(coalesce(entry->>'color','')))=0 OR length(btrim(coalesce(entry->>'size','')))=0 THEN RAISE EXCEPTION 'Each variant needs a colour and size';END IF;
  vid:=coalesce(nullif(entry->>'id','')::uuid,gen_random_uuid());ids:=array_append(ids,vid);
  INSERT INTO public.product_variants(id,product_id,color,color_hex,size,active)
  VALUES(vid,pid,btrim(entry->>'color'),coalesce(entry->>'color_hex','#222222'),btrim(entry->>'size'),true)
  ON CONFLICT(id) DO UPDATE SET color=excluded.color,color_hex=excluded.color_hex,size=excluded.size,active=true WHERE product_variants.product_id=pid;
  GET DIAGNOSTICS counted=ROW_COUNT;IF counted<>1 THEN RAISE EXCEPTION 'Variant belongs to another product';END IF;
 END LOOP;
 UPDATE public.product_variants SET active=false WHERE product_id=pid AND NOT(id=ANY(ids));
 FOR entry IN SELECT * FROM jsonb_array_elements(payload->'images') LOOP
  image_path_value:=entry->>'path';
  IF image_path_value IS NULL OR image_path_value NOT LIKE pid::text||'/%' OR NOT (EXISTS(SELECT 1 FROM private.hood_packaged_assets a WHERE a.path=image_path_value) OR EXISTS(SELECT 1 FROM storage.objects s WHERE s.bucket_id='product-images' AND s.name=image_path_value)) THEN RAISE EXCEPTION 'Upload a valid product photograph';END IF;
 END LOOP;
 DELETE FROM public.product_images WHERE product_id=pid;
 INSERT INTO public.product_images(product_id,path,color,alt,position)
 SELECT pid,e->>'path',nullif(e->>'color',''),coalesce(e->>'alt',payload->>'name'),n::integer-1 FROM jsonb_array_elements(payload->'images') WITH ORDINALITY a(e,n);
 RETURN pid;
END $function$
;

DROP TRIGGER IF EXISTS hood_restore_bundle_stock ON public.orders;
NOTIFY pgrst,'reload schema';

COMMIT;
