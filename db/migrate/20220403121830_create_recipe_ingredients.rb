class CreateRecipeIngredients < ActiveRecord::Migration[6.1]
  def change
    create_table :recipe_ingredients, id: :uuid do |t|
      t.references :recipe, foreign_key: true, null: false, index: true, type: :uuid
      t.string :ingredient_description, null: false

      t.timestamps default: -> { 'CURRENT_TIMESTAMP' }
    end
  end
end
