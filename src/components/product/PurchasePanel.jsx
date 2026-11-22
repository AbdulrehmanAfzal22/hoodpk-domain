import {whatsappLink,customisationMessage} from '../../config/hoodStore';
import {useState} from 'react';
import {Heart,Minus,Plus} from 'lucide-react';

export default function PurchasePanel({selectedVariant,onAddToCart,onWishlist,onBuyNow,product,colour,size,busy}){
  const [quantity,setQuantity]=useState(1);
  const maximum=99;

  function updateQuantity(next){setQuantity(Math.max(1,Math.min(maximum,next)));}

  return <div className="product-purchase">
    <div className="product-quantity" aria-label="Quantity">
      <button type="button" onClick={()=>updateQuantity(quantity-1)} disabled={quantity<=1} aria-label="Decrease quantity"><Minus size={15}/></button>
      <output aria-live="polite">{quantity}</output>
      <button type="button" onClick={()=>updateQuantity(quantity+1)} disabled={quantity>=maximum} aria-label="Increase quantity"><Plus size={15}/></button>
    </div>
    <button className="product-add-to-bag" type="button" onClick={()=>onAddToCart(quantity)} disabled={busy||!selectedVariant}>{busy?'Adding to bag':'Add to Cart'}</button>
    <button className="hood-buy-now" type="button" onClick={()=>onBuyNow(quantity)} disabled={busy||!selectedVariant}>Buy Now</button>
    {(/custom|t-shirt/i.test(product?.categories?.slug||'')||product?.customisable)&&<a className="hood-customise-product" href={whatsappLink(customisationMessage({name:product?.name,colour,size,quantity,url:typeof window!=='undefined'?window.location.href:''}))} target="_blank" rel="noreferrer">Customise on WhatsApp ↗</a>}
    <button className="product-save" type="button" onClick={onWishlist} aria-label="Add to wishlist"><Heart size={19}/></button>
  </div>;
}