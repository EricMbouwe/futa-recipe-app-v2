import { ApiError, searchRecipes } from "./recipes.js";

const okResponse = (body) => ({ ok: true, status: 200, json: async () => body });

afterEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
  vi.resetModules();
});

test("encode les paramètres et convertit la réponse (régression WEB-03)", async () => {
  const fetchMock = vi.fn().mockResolvedValue(okResponse({ recipes: [], page: 2, total_count: 41 }));
  vi.stubGlobal("fetch", fetchMock);

  const result = await searchRecipes({ ingredients: [ "crème fraîche", "salt & pepper" ], page: 2 });

  const [ url, options ] = fetchMock.mock.calls[0];
  expect(url).toBe("/v1/recipes/search?ingredients=cr%C3%A8me+fra%C3%AEche%2Csalt+%26+pepper&page=2&count_per_page=20");
  expect(options.headers).toEqual({ Accept: "application/json" });
  expect(result).toEqual({ recipes: [], page: 2, totalCount: 41 });
});

test("envoie X-Api-Key quand VITE_API_KEY est défini", async () => {
  vi.stubEnv("VITE_API_KEY", "k-123");
  vi.resetModules();
  const { searchRecipes: search } = await import("./recipes.js");
  const fetchMock = vi.fn().mockResolvedValue(okResponse({ recipes: [], page: 1, total_count: 0 }));
  vi.stubGlobal("fetch", fetchMock);

  await search({ ingredients: [ "rice" ], page: 1 });

  expect(fetchMock.mock.calls[0][1].headers).toEqual({ Accept: "application/json", "X-Api-Key": "k-123" });
});

test.each([
  [ 401, /requires an api key/i ],
  [ 422, /isn't valid/i ],
  [ 429, /too many searches/i ],
  [ 503, /error \(503\)/i ],
])("traduit le statut %i en message utilisateur", async (status, message) => {
  vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status, json: async () => ({}) }));

  const error = await searchRecipes({ ingredients: [ "rice" ], page: 1 }).catch((caught) => caught);

  expect(error).toBeInstanceOf(ApiError);
  expect(error.status).toBe(status);
  expect(error.message).toMatch(message);
});

test("signale une panne réseau", async () => {
  vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("Failed to fetch")));

  await expect(searchRecipes({ ingredients: [ "rice" ], page: 1 })).rejects.toThrow(/can't reach the server/i);
});

test("laisse passer une annulation", async () => {
  vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new DOMException("Aborted", "AbortError")));

  await expect(searchRecipes({ ingredients: [ "rice" ], page: 1 })).rejects.toHaveProperty("name", "AbortError");
});
