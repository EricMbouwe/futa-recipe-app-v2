export default function IngredientList({ ingredients, onRemove }) {
  if (ingredients.length === 0) {
    return <p className="muted">No ingredients yet. Add what's in your kitchen.</p>;
  }

  return (
    <ul className="chips" aria-label="Your ingredients">
      {ingredients.map((ingredient) => (
        <li key={ingredient} className="chip">
          {ingredient}
          <button type="button" onClick={() => onRemove(ingredient)} aria-label={`Remove ${ingredient}`}>×</button>
        </li>
      ))}
    </ul>
  );
}
