import {normaliseColour} from '../../lib/productOptions';

export default function VariantSelector({options,allVariants=[],colourSwatches=[],size,onColorChange,onSizeChange}){
  const colorOptions=[...new Map(options.colours.map(color=>[color,allVariants.find(variant=>variant.active&&variant.color===color)||colourSwatches.find(option=>normaliseColour(option.color)===normaliseColour(color))]))];

  return <div className="product-variant-selector">
    {options.colours.length>0&&<fieldset className="product-color-selector"><legend>Colour <span>{options.colour}</span></legend><div className="product-color-selector__options">{colorOptions.map(([color,variant])=><button key={color} type="button" className={options.colour===color?'is-selected':''} title={color} aria-label={`Choose ${color} colour`} aria-pressed={options.colour===color} onClick={()=>onColorChange(color)}><span style={{'--variant-swatch':variant?.color_hex||'#d8d2c9'}}/></button>)}</div></fieldset>}
    {options.variants.length>0&&<fieldset className="product-size-selector"><legend>Size <span>{size||'Select a size'}</span></legend><div className="product-size-selector__options">{options.variants.map(variant=>{
      return <button key={variant.id} type="button" className={`${size===variant.size?'is-selected':''}`} aria-pressed={size===variant.size} aria-label={`${variant.size}`} onClick={()=>onSizeChange(variant.size)}>{variant.size}</button>;
    })}</div></fieldset>}
  </div>;
}