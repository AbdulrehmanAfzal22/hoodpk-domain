import {categoryWideBundleSlugs} from '../lib/bundleChoiceOptions.mjs';
import {bundlePhotoOptions} from '../lib/bundleCardTiles.mjs';
import ProductPrice from '../components/ProductPrice';
import {useState} from 'react';
import {Link} from 'react-router-dom';
import {useProducts} from '../hooks/useProducts';
import {saveBundle} from '../services/bundles';
import {imageUrl,money} from '../lib/supabase';
import {Loading,ErrorState} from '../components/Feedback';
import {toast} from 'sonner';
import '../styles/bundles.css';
export default function Bundles(){
 const q=useProducts({admin:true}),[form,setForm]=useState(null),[search,setSearch]=useState(''),[busy,setBusy]=useState(false),[error,setError]=useState('');
 const products=q.data||[],bundles=products.filter(p=>p.is_bundle),choices=products.filter(p=>!p.is_bundle&&(!search||(p.name+' '+p.categories?.name).toLowerCase().includes(search.toLowerCase())));
 const edit=p=>{setError('');setSearch('');setForm(p?{id:p.id,name:p.name,description:p.description||'',price:String(p.price_cents/100),productIds:p.bundle_components.map(x=>x.id),coverPaths:Object.fromEntries(p.bundle_components.map(x=>[x.id,bundlePhotoOptions(x).some(photo=>photo.path===x.bundle_cover_path)?x.bundle_cover_path:''])),status:p.status}:{id:null,name:'',description:'',price:'',productIds:[],coverPaths:{},status:'draft'});};
 const change=(key,value)=>setForm(previous=>({...previous,[key]:value}));
 function toggleProduct(id,selected){
  setForm(previous=>{
   const coverPaths={...previous.coverPaths};
   if(!selected)delete coverPaths[id];
   return {...previous,coverPaths,productIds:selected?[...previous.productIds,id]:previous.productIds.filter(productId=>productId!==id)};
  });
 }
 async function submit(e){e.preventDefault();setBusy(true);setError('');try{if(form.productIds.length<2)throw new Error('Select at least two products.');await saveBundle(form);await q.refresh();setForm(null);toast.success('Bundle saved');}catch(e){setError(e.message);}finally{setBusy(false);}}
 if(q.loading&&!q.data)return <Loading/>;if(q.error)return <ErrorState error={q.error} retry={q.refresh}/>;
 return <><div className="section-heading"><div><p className="eyebrow">CREATE YOUR OWN OFFERS</p><h1>Combos & Bundles</h1><p>Select two or more products and set one fixed bundle price.</p></div><button className="button" onClick={()=>edit()}>Create bundle</button></div>{form&&<form className="panel" onSubmit={submit}><div className="section-heading"><h2>{form.id?'Edit bundle':'New bundle'}</h2><button type="button" className="text-button" onClick={()=>setForm(null)} disabled={busy}>Cancel</button></div><div className="bundle-admin-fields"><label>Bundle name<input required maxLength={200} value={form.name} onChange={e=>change('name',e.target.value)}/></label><label>Fixed price (PKR)<input required type="number" step="0.01" min="0.01" max="1000000" value={form.price} onChange={e=>change('price',e.target.value)}/></label><label>Status<select value={form.status} onChange={e=>change('status',e.target.value)}><option value="draft">Draft</option><option value="published">Published — show in store</option><option value="archived">Archived</option></select></label></div><label>Description<textarea rows={3} maxLength={8000} value={form.description} onChange={e=>change('description',e.target.value)}/></label><h3>Products · {form.productIds.length} selected</h3><input type="search" value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search all products" aria-label="Search bundle products"/><div className="bundle-admin-picker">{choices.map(p=>{const eligible=p.status==='published'&&!p.enquiry_only&&p.product_variants.some(v=>v.active);return <label className={`bundle-picker-item ${form.productIds.includes(p.id)?'is-selected':''}`} key={p.id}><input type="checkbox" checked={form.productIds.includes(p.id)} disabled={busy||!eligible} onChange={e=>toggleProduct(p.id,e.target.checked)}/>{p.product_images?.[0]&&<img src={imageUrl(p.product_images[0].path)} alt=""/>}<span><strong>{p.name}</strong><small>{eligible?`${p.categories?.name} · ${money(p.price_cents)}`:'Publish and add priced colour and size options first'}</small></span></label>})}</div><BundleCoverPicker productIds={form.productIds} products={products} coverPaths={form.coverPaths} disabled={busy} onChange={(id,path)=>setForm(previous=>({...previous,coverPaths:{...previous.coverPaths,[id]:path}}))}/><p className="muted">Each chosen product appears once. Customers select its colour and size. Updating a bundle requires existing cart selections to be chosen again.</p>{error&&<p className="error" role="alert">{error}</p>}<button className="button" disabled={busy||form.productIds.length<2}>{busy?'Saving…':'Save bundle'}</button></form>}<div>{bundles.map(p=><article className="panel bundle-admin-card" key={p.id}><div className="bundle-cover-grid">{p.product_images.map((im,i)=><img src={imageUrl(im.path)} key={i} alt=""/>)}</div><div><p className="eyebrow">{p.status}</p><h2>{p.name}</h2><p>{p.bundle_components.length} products · <ProductPrice product={p}/></p><div className="bundle-admin-actions"><button className="button" onClick={()=>edit(p)}>Edit bundle</button>{p.status==='published'&&<Link className="text-button" to={`/product/${p.id}`}>View in store ↗</Link>}</div></div></article>)}</div>{!form&&!bundles.length&&<div className="state"><h2>Your first bundle starts here</h2><p>Create a set using any two or more available products.</p></div>}</>;
}

function BundleCoverPicker({productIds,products,coverPaths,disabled,onChange}){
 if(!productIds.length)return null;
 return <section className="bundle-photo-picker" aria-label="Bundle cover photos">
  <h3>Bundle cover photos</h3>
  {productIds.map(id=>{
   const product=products.find(item=>item.id===id);
   if(!product)return null;
   const related=categoryWideBundleSlugs.includes(product.categories?.slug)
    ? products.filter(item=>item.category_id===product.category_id&&!item.is_bundle&&!item.enquiry_only&&item.status==='published')
    : [];
   const photos=bundlePhotoOptions({...product,bundle_choice_products:related});
   if(!photos.length)return null;
   const selected=photos.some(photo=>photo.path===coverPaths[id])?coverPaths[id]:'';
   return <fieldset key={id} disabled={disabled}>
    <legend>{product.name}</legend>
    <div className="bundle-photo-picker__options">
     <label><input type="radio" name={`bundle-photo-${id}`} checked={!selected} onChange={()=>onChange(id,'')}/> Default cover</label>
     {photos.map((photo,index)=><label key={photo.path}>
      <input type="radio" name={`bundle-photo-${id}`} checked={selected===photo.path} onChange={()=>onChange(id,photo.path)}/>
      <img src={imageUrl(photo.path)} alt="" loading="lazy"/>
      <span>{photo.color||photo.productName} · Photo {index+1}</span>
     </label>)}
    </div>
   </fieldset>;
  })}
 </section>;
}
