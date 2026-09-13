import { addIngredients, MAX_INGREDIENTS, removeIngredient } from "./ingredients.js";

describe("addIngredients", () => {
  test("normalise espaces et casse", () => {
    expect(addIngredients([], "  White   RICE ")).toEqual([ "white rice" ]);
  });

  test("découpe une saisie contenant des virgules et déduplique", () => {
    expect(addIngredients([ "rice" ], "bread, RICE,,eggs")).toEqual([ "rice", "bread", "eggs" ]);
  });

  test("renvoie la même liste quand rien n'est ajouté", () => {
    const list = [ "rice" ];

    expect(addIngredients(list, " , ")).toBe(list);
  });

  test(`plafonne à ${MAX_INGREDIENTS} ingrédients, comme l'API`, () => {
    const full = Array.from({ length: MAX_INGREDIENTS }, (_, index) => `item ${index}`);

    expect(addIngredients(full, "rice")).toBe(full);
  });
});

test("removeIngredient retire un terme", () => {
  expect(removeIngredient([ "rice", "bread" ], "rice")).toEqual([ "bread" ]);
});
