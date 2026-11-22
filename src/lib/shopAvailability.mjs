export function matchesVariantFilters(product,{color='',size=''}={}){
 const active=(product.product_variants||[]).filter(variant=>variant.active);
 if(!color&&!size)return true;
 if(product.enquiry_only)return !size&&(!color||(product.inquiry_colours||[]).some(option=>option.color===color));
 return active.some(variant=>(!color||variant.color===color)&&(!size||variant.size===size));
}
