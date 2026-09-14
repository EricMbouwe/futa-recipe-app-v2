import ReactPaginate from "react-paginate";
import RecipeCard from "./RecipeCard.jsx";
import { PER_PAGE } from "../api/recipes.js";

export default function SearchResults({ status, error, result, onPageChange, onRetry }) {
  if (status === "idle") return null;

  if (status === "loading") {
    return <p role="status" className="muted">Searching recipes…</p>;
  }

  if (status === "error") {
    return (
      <div role="alert" className="alert">
        <p>{error}</p>
        <button type="button" onClick={onRetry}>Try again</button>
      </div>
    );
  }

  if (result.totalCount === 0) {
    return <p role="status">No recipe uses these ingredients. Try removing one.</p>;
  }

  const pageCount = Math.ceil(result.totalCount / PER_PAGE);

  return (
    <section aria-labelledby="results-title">
      <h2 id="results-title">
        {result.totalCount} {result.totalCount === 1 ? "recipe" : "recipes"} found
      </h2>
      <div className="recipe-grid">
        {result.recipes.map((recipe) => <RecipeCard key={recipe.id} recipe={recipe} />)}
      </div>
      {pageCount > 1 && (
        <ReactPaginate
          pageCount={pageCount}
          forcePage={result.page - 1}
          onPageChange={({ selected }) => onPageChange(selected + 1)}
          pageRangeDisplayed={2}
          marginPagesDisplayed={1}
          previousLabel="Previous"
          nextLabel="Next"
          containerClassName="pagination"
          activeClassName="is-active"
          disabledClassName="is-disabled"
        />
      )}
    </section>
  );
}
