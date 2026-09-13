export const MAX_INGREDIENTS = 20;

const normalize = (term) => term.trim().replace(/\s+/g, " ").toLowerCase();

// Ajoute une saisie (éventuellement "rice, eggs") : termes normalisés, sans vide ni doublon,
// dans la limite acceptée par l'API. Renvoie la même liste si rien n'est ajouté.
export function addIngredients(list, raw) {
  return raw.split(",").map(normalize).reduce((accumulator, term) => {
    if (term === "" || accumulator.includes(term) || accumulator.length >= MAX_INGREDIENTS) return accumulator;
    return [ ...accumulator, term ];
  }, list);
}

export function removeIngredient(list, term) {
  return list.filter((item) => item !== term);
}
