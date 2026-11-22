export const normaliseColour = value => String(value || '').trim().toLowerCase();

export function productOptions(variants = [], requestedColour = '', requestedSize = '', swatches = []) {
  const active = variants.filter(variant => variant.active);
  const colours = [...new Map([...swatches,...active].map(option => [normaliseColour(option.color), option.color])).values()];
  const colour = colours.find(value => normaliseColour(value) === normaliseColour(requestedColour)) || active[0]?.color || colours[0] || '';
  const colourVariants=active.filter(variant => normaliseColour(variant.color) === normaliseColour(colour));
  const selectedVariant=colourVariants.find(variant=>variant.size===requestedSize) || colourVariants[0];
  return { colours, colour, variants: colourVariants, selectedVariant };
}

export function galleryImages(images = [], colour = '') {
  const sorted = [...images].sort((a, b) => a.position - b.position);
  const matching = sorted.filter(image => normaliseColour(image.color) === normaliseColour(colour) && image.color);
  const general = sorted.filter(image => !image.color?.trim());
  if(matching.length)return [...matching,...general];
  // Keep the cover even when every uploaded image has a colour label.
  const cover=sorted[0];
  return cover?[cover,...general.filter(image=>image!==cover)]:[];
}
