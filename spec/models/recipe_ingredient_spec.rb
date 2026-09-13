require "rails_helper"

RSpec.describe RecipeIngredient do
  it "est valide avec la factory" do
    expect(build(:recipe_ingredient)).to be_valid
  end

  it "exige une recette et une description" do
    ingredient = build(:recipe_ingredient, recipe: nil, ingredient_description: " ")

    expect(ingredient).not_to be_valid
    expect(ingredient.errors.attribute_names).to contain_exactly(:recipe, :ingredient_description)
  end
end
