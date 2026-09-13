export default function RecipeCard({ recipe }) {
  return (
    <article className="recipe-card">
      <img src={recipe.result_image_url} alt={recipe.name} width={320} height={240} loading="lazy" />
      <div className="recipe-card__body">
        <h3>{recipe.name}</h3>
        <p className="recipe-card__meta">
          <span>{recipe.duration_in_mins} min</span>
          {recipe.category && <span>{recipe.category}</span>}
        </p>
        <details>
          <summary>{recipe.ingredients.length} ingredients</summary>
          <ul>
            {recipe.ingredients.map((ingredient, index) => <li key={index}>{ingredient}</li>)}
          </ul>
        </details>
      </div>
    </article>
  );
}
