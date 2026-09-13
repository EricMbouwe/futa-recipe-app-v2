export const PER_PAGE = 20;

const API_URL = (import.meta.env.VITE_API_URL ?? "").replace(/\/+$/, "");
const API_KEY = import.meta.env.VITE_API_KEY;

export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

const MESSAGES = {
  401: "This server requires an API key. Ask its administrator to rebuild the site with one.",
  422: "One of your ingredients isn't valid. Use 2 to 40 letters, numbers, spaces, hyphens or apostrophes.",
  429: "Too many searches in a short time. Wait a minute, then try again.",
};

export async function searchRecipes({ ingredients, page, perPage = PER_PAGE, signal }) {
  const params = new URLSearchParams({
    ingredients: ingredients.join(","),
    page: String(page),
    count_per_page: String(perPage),
  });
  const headers = { Accept: "application/json" };
  if (API_KEY) headers["X-Api-Key"] = API_KEY;

  let response;
  try {
    response = await fetch(`${API_URL}/v1/recipes/search?${params}`, { headers, signal });
  } catch (error) {
    if (error.name === "AbortError") throw error;
    throw new ApiError("Can't reach the server. Check your connection, then try again.", 0);
  }

  if (!response.ok) {
    const message = MESSAGES[response.status] ?? `The server returned an error (${response.status}). Try again in a moment.`;
    throw new ApiError(message, response.status);
  }

  const body = await response.json();
  return { recipes: body.recipes, page: body.page, totalCount: body.total_count };
}
