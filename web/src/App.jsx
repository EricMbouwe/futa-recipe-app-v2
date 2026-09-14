import { useCallback, useEffect, useRef, useState } from "react";
import IngredientForm from "./components/IngredientForm.jsx";
import IngredientList from "./components/IngredientList.jsx";
import SearchResults from "./components/SearchResults.jsx";
import { searchRecipes } from "./api/recipes.js";
import { addIngredients, MAX_INGREDIENTS, removeIngredient } from "./lib/ingredients.js";
import "./App.css";

const EMPTY_RESULT = { recipes: [], page: 1, totalCount: 0 };

export default function App() {
  const [ingredients, setIngredients] = useState([]);
  const [draft, setDraft] = useState("");
  const [status, setStatus] = useState("idle");
  const [result, setResult] = useState(EMPTY_RESULT);
  const [error, setError] = useState(null);
  // La dernière requête envoyée : la pagination et « Try again » la rejouent telle quelle.
  const [lastRequest, setLastRequest] = useState(null);
  const inFlight = useRef(null);

  useEffect(() => () => inFlight.current?.abort(), []);

  const load = useCallback(async (request) => {
    inFlight.current?.abort();
    const controller = new AbortController();
    inFlight.current = controller;

    setLastRequest(request);
    setStatus("loading");
    setError(null);

    try {
      setResult(await searchRecipes({ ...request, signal: controller.signal }));
      setStatus("success");
    } catch (caught) {
      if (caught.name === "AbortError") return;
      setError(caught.message);
      setStatus("error");
    }
  }, []);

  const handleAdd = () => {
    setIngredients((list) => addIngredients(list, draft));
    setDraft("");
  };

  const handleSearch = () => {
    const list = addIngredients(ingredients, draft);
    setIngredients(list);
    setDraft("");
    load({ ingredients: list, page: 1 });
  };

  const handleReset = () => {
    inFlight.current?.abort();
    setIngredients([]);
    setDraft("");
    setResult(EMPTY_RESULT);
    setError(null);
    setLastRequest(null);
    setStatus("idle");
  };

  const canSearch = (ingredients.length > 0 || draft.trim() !== "") && status !== "loading";

  return (
    <main className="app">
      <header className="app__header">
        <h1>Futa Recipes</h1>
        <p>Tell us what's in your kitchen. We'll find the recipes that use the most of it.</p>
      </header>

      <section className="panel" aria-labelledby="ingredients-title">
        <h2 id="ingredients-title">What ingredients do you have?</h2>
        <IngredientForm
          value={draft}
          onChange={setDraft}
          onSubmit={handleAdd}
          atLimit={ingredients.length >= MAX_INGREDIENTS}
        />
        <IngredientList
          ingredients={ingredients}
          onRemove={(term) => setIngredients((list) => removeIngredient(list, term))}
        />
        <div className="actions">
          <button type="button" className="primary" onClick={handleSearch} disabled={!canSearch}>
            Find recipes
          </button>
          <button type="button" onClick={handleReset}>Reset</button>
        </div>
      </section>

      <SearchResults
        status={status}
        error={error}
        result={result}
        onPageChange={(page) => load({ ingredients: lastRequest.ingredients, page })}
        onRetry={() => load(lastRequest)}
      />
    </main>
  );
}
