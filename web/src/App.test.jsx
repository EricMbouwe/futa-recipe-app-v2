import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import App from "./App.jsx";

const recipe = (n) => ({
  id: `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`,
  name: `Recipe ${n}`,
  duration_in_mins: 30,
  category: "Dinner",
  result_image_url: `https://images.example.com/${n}.jpg`,
  ingredients: [ "1 cup rice" ],
});
const ok = (body) => ({ ok: true, status: 200, json: async () => body });
const failure = (status) => ({ ok: false, status, json: async () => ({}) });

function mockFetch(...responses) {
  const fetchMock = vi.fn();
  responses.forEach((response) => fetchMock.mockResolvedValueOnce(response));
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

const paramsOf = (fetchMock, call = 0) => new URL(fetchMock.mock.calls[call][0], "http://localhost").searchParams;
const input = () => screen.getByLabelText(/add an ingredient/i);
const findButton = () => screen.getByRole("button", { name: /find recipes/i });

afterEach(() => vi.unstubAllGlobals());

test("affiche le formulaire de saisie des ingrédients", () => {
  render(<App />);

  expect(screen.getByRole("heading", { name: /what ingredients do you have/i })).toBeInTheDocument();
  expect(findButton()).toBeDisabled();
});

test("recherche avec les ingrédients saisis et affiche le nombre de résultats", async () => {
  const user = userEvent.setup();
  const fetchMock = mockFetch(ok({ recipes: [ recipe(1), recipe(2) ], page: 1, total_count: 2 }));
  render(<App />);

  await user.type(input(), "Rice{Enter}");
  await user.type(input(), "bread{Enter}");
  await user.click(findButton());

  expect(await screen.findByRole("heading", { name: "2 recipes found" })).toBeInTheDocument();
  expect(screen.getAllByRole("article")).toHaveLength(2);
  expect(paramsOf(fetchMock).get("ingredients")).toBe("rice,bread");
  expect(paramsOf(fetchMock).get("page")).toBe("1");
  expect(paramsOf(fetchMock).get("count_per_page")).toBe("20");
});

test("demande la page cliquée et dérive le nombre de pages de total_count (régressions WEB-01, WEB-02)", async () => {
  const user = userEvent.setup();
  const fetchMock = mockFetch(
    ok({ recipes: [ recipe(1) ], page: 1, total_count: 45 }),
    ok({ recipes: [ recipe(21) ], page: 2, total_count: 45 }),
  );
  render(<App />);

  await user.type(input(), "rice{Enter}");
  await user.click(findButton());
  await screen.findByRole("heading", { name: "45 recipes found" });

  expect(screen.getByRole("button", { name: "Page 3" })).toBeInTheDocument();
  expect(screen.queryByRole("button", { name: "Page 4" })).not.toBeInTheDocument();

  await user.click(screen.getByRole("button", { name: "Page 2" }));

  expect(await screen.findByText("Recipe 21")).toBeInTheDocument();
  expect(paramsOf(fetchMock, 1).get("page")).toBe("2");
  expect(paramsOf(fetchMock, 1).get("ingredients")).toBe("rice");
});

test("pagine sur la recherche lancée, même si la liste a changé depuis", async () => {
  const user = userEvent.setup();
  const fetchMock = mockFetch(
    ok({ recipes: [ recipe(1) ], page: 1, total_count: 45 }),
    ok({ recipes: [ recipe(21) ], page: 2, total_count: 45 }),
  );
  render(<App />);

  await user.type(input(), "rice{Enter}");
  await user.click(findButton());
  await screen.findByRole("heading", { name: "45 recipes found" });
  await user.type(input(), "bread{Enter}");
  await user.click(screen.getByRole("button", { name: "Page 2" }));

  await screen.findByText("Recipe 21");
  expect(paramsOf(fetchMock, 1).get("ingredients")).toBe("rice");
});

test("inclut l'ingrédient tapé mais pas encore ajouté", async () => {
  const user = userEvent.setup();
  const fetchMock = mockFetch(ok({ recipes: [], page: 1, total_count: 0 }));
  render(<App />);

  await user.type(input(), "eggs");
  await user.click(findButton());

  expect(await screen.findByText(/no recipe uses these ingredients/i)).toBeInTheDocument();
  expect(paramsOf(fetchMock).get("ingredients")).toBe("eggs");
  expect(input()).toHaveValue("");
});

test("affiche une erreur compréhensible et permet de réessayer", async () => {
  const user = userEvent.setup();
  const fetchMock = mockFetch(failure(429), ok({ recipes: [ recipe(1) ], page: 1, total_count: 1 }));
  render(<App />);

  await user.type(input(), "rice{Enter}");
  await user.click(findButton());

  expect(await screen.findByRole("alert")).toHaveTextContent(/too many searches/i);

  await user.click(screen.getByRole("button", { name: /try again/i }));

  expect(await screen.findByRole("heading", { name: "1 recipe found" })).toBeInTheDocument();
  expect(fetchMock).toHaveBeenCalledTimes(2);
});

test("ignore doublons et saisies vides ; Reset vide la liste et le champ (régression WEB-04)", async () => {
  const user = userEvent.setup();
  render(<App />);

  await user.type(input(), "rice{Enter}");
  await user.type(input(), " RICE {Enter}");
  const list = screen.getByRole("list", { name: /your ingredients/i });
  expect(within(list).getAllByRole("listitem")).toHaveLength(1);

  await user.click(screen.getByRole("button", { name: "Remove rice" }));
  expect(screen.queryByRole("list", { name: /your ingredients/i })).not.toBeInTheDocument();

  await user.type(input(), "bread{Enter}");
  await user.type(input(), "salt");
  await user.click(screen.getByRole("button", { name: /reset/i }));

  expect(input()).toHaveValue("");
  expect(screen.queryByRole("list", { name: /your ingredients/i })).not.toBeInTheDocument();
});
