import {uploadedProducts} from './uploadedCatalogue.mjs';
import {normaliseColour} from './productOptions.js';
export function storeColourPalette(products=[]){
 const source=products.find(p=>p.categories?.slug==='plain-hoodies'&&p.inquiry_colours?.length)||products.find(p=>p.inquiry_colours?.length);
 const options=source?.inquiry_colours||[];
 return [...new Map(options.filter(c=>c.color?.trim()).map(c=>[normaliseColour(c.color),{color:c.color.trim(),color_hex:c.color_hex||'#24211e'}])).values()];
}
export const defaultProductColours=storeColourPalette(uploadedProducts).slice(0,12);

export function withDefaultProductColours(colours=[]){
 const byName=new Map(defaultProductColours.map(colour=>[normaliseColour(colour.color),colour]));
 for(const colour of colours){
  if(colour.color?.trim())byName.set(normaliseColour(colour.color),colour);
 }
 return [...byName.values()];
}

export function addColourVariants(existing=[],colours=[],sizes=['S','M','L','XL'],makeId){
 const rows=existing.filter(v=>v.color?.trim()&&v.size?.trim()).map(v=>({...v}));
 const keys=new Set(rows.map(v=>normaliseColour(v.color)+'|'+v.size.trim().toLowerCase()));
 for(const colour of colours)for(const rawSize of sizes){const size=rawSize.trim();if(!size)continue;const key=normaliseColour(colour.color)+'|'+size.toLowerCase();if(keys.has(key))continue;keys.add(key);rows.push({id:makeId(),color:colour.color,color_hex:colour.color_hex,size,active:true});}
 return rows;
}
