export const categoryWideBundleSlugs=['plain-hoodies','sweatshirts','zipper-hoodies'];
export function bundleChoiceOptions(component){
 const seed=component.product_variants?component:component.bundle_choice_products?.find(product=>product.id===component.id)||component;
 const products=[seed,...(component.bundle_choice_products||[]).filter(product=>product.id!==component.id)];
 const options=new Map();
 const hasPhoto=(product,colour)=>(product.product_images||[]).some(image=>image.color?.trim().toLowerCase()===colour);
 for(const product of products){
  for(const variant of product.product_variants||[]){
   if(!variant.active)continue;
   const colour=variant.color.trim().toLowerCase();
   const key=colour+'|'+variant.size.trim().toLowerCase();
   const previous=options.get(key);
   if(!previous||(!hasPhoto(previous.product,colour)&&hasPhoto(product,colour)))options.set(key,{product,variant});
  }
 }
 return [...options.values()];
}
