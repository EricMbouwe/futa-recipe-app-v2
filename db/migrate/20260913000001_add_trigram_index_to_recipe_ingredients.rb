class AddTrigramIndexToRecipeIngredients < ActiveRecord::Migration[7.2]
  # CREATE INDEX CONCURRENTLY ne peut pas s'exécuter dans une transaction.
  disable_ddl_transaction!

  def change
    enable_extension "pg_trgm"

    add_index :recipe_ingredients, :ingredient_description,
      using: :gin,
      opclass: :gin_trgm_ops,
      algorithm: :concurrently,
      name: "index_recipe_ingredients_on_description_trgm"
  end
end
