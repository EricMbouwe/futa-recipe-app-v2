export default function IngredientForm({ value, onChange, onSubmit, atLimit }) {
  const handleSubmit = (event) => {
    event.preventDefault();
    onSubmit();
  };

  return (
    <form className="ingredient-form" onSubmit={handleSubmit}>
      <label htmlFor="ingredient-input">Add an ingredient</label>
      <div className="ingredient-form__row">
        <input
          id="ingredient-input"
          type="text"
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder="e.g. rice, eggs"
          autoComplete="off"
          disabled={atLimit}
        />
        <button type="submit" disabled={atLimit || value.trim() === ""}>Add</button>
      </div>
      {atLimit && <p className="hint">You've reached 20 ingredients. Remove one to add another.</p>}
    </form>
  );
}
