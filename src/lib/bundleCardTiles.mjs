export function bundlePhotoOptions(component){
 const products=[component,...(component.bundle_choice_products||[]).filter(product=>product.id!==component.id)];
 const photos=new Map();
 for(const product of products){
  for(const image of [...(product.product_images||[])].sort((a,b)=>a.position-b.position)){
   if(image.path&&!photos.has(image.path))photos.set(image.path,{...image,productName:product.name});
  }
 }
 return [...photos.values()];
}
export function bundleCoverPhoto(component){
 const ownPhotos=[...(component.product_images||[])].sort((a,b)=>a.position-b.position);
 return (component.bundle_cover_path&&bundlePhotoOptions(component).find(photo=>photo.path===component.bundle_cover_path))||ownPhotos[0];
}

export function bundleCardTiles(product){
 const components=product?.bundle_components||[];
 if(components.length)return components.map(component=>({id:component.id,name:component.name,path:bundleCoverPhoto(component)?.path||null}));
 return [...(product?.product_images||[])].sort((a,b)=>a.position-b.position).map((image,i)=>({id:image.id||String(i),name:image.alt||'Included product',path:image.path}));
}
