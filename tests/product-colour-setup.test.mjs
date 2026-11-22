import test from 'node:test';
import assert from 'node:assert/strict';
import {addColourVariants,storeColourPalette,defaultProductColours} from '../src/lib/productColourSetup.js';
import {galleryImages,productOptions} from '../src/lib/productOptions.js';
test('colour options do not depend on uploaded photos and missing photos keep the cover',()=>{
 const variants=[{id:'blue',active:true,color:'Blue',size:'M',stock:4},{id:'black',active:true,color:'Black',size:'M',stock:2}];
 assert.equal(productOptions(variants,'Blue').colour,'Blue');
 const cover={path:'black.jpg',color:'Black',position:0};
 assert.equal(galleryImages([cover],'Blue')[0].path,'black.jpg');
 assert.equal(galleryImages([cover,{path:'blue.jpg',color:' BLUE ',position:1}],'Blue')[0].path,'blue.jpg');
 assert.equal(variants[0].color,'Blue');
});
test('adding store colours preserves existing options and avoids duplicate combinations',()=>{
 const original=[{id:'old',color:'Black',size:'M',stock:7}];let n=0;
 const rows=addColourVariants(original,[{color:'black',color_hex:'#000'},{color:'Blue',color_hex:'#00f'}],['M','L','M'],()=>String(++n));
 assert.equal(rows.length,4);assert.deepEqual(rows[0],original[0]);assert.ok(rows.slice(1).every(v=>!('stock' in v)));assert.equal(original.length,1);
});
test('default palette comes from the store hoodie list and generates options without inventory',()=>{
 const palette=storeColourPalette([{categories:{slug:'plain-hoodies'},inquiry_colours:[{color:'Black'},{color:'Blue'},{color:' black '}]}]);
 assert.equal(palette.length,2);let n=0;assert.ok(addColourVariants([],palette,['S','M'],()=>String(++n)).every(v=>!('stock' in v)));
});

test('the 12 default colour swatches can be selected with one photo and without creating inventory',()=>{
 const variants=[{id:'black',active:true,color:'Black',size:'M',stock:2}];
 const result=productOptions(variants,'Baby Blue','',defaultProductColours);
 assert.equal(result.colours.length,12);
 assert.equal(result.colour,'Baby Blue');
 assert.equal(result.variants.length,0);
 assert.equal(galleryImages([{path:'cover.jpg',position:0}],result.colour)[0].path,'cover.jpg');
});
