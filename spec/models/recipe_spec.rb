require "rails_helper"

RSpec.describe Recipe do
  it "est valide avec la factory" do
    expect(build(:recipe)).to be_valid
  end

  it "exige un nom et une image" do
    recipe = build(:recipe, name: "", result_image_url: nil)

    expect(recipe).not_to be_valid
    expect(recipe.errors.attribute_names).to contain_exactly(:name, :result_image_url)
  end

  it "accepte une catégorie vide (65 recettes du jeu de données) mais pas nil" do
    expect(build(:recipe, category: "")).to be_valid
    expect(build(:recipe, category: nil)).not_to be_valid
  end

  it "refuse une durée négative ou non entière" do
    expect(build(:recipe, duration_in_mins: -1)).not_to be_valid
    expect(build(:recipe, duration_in_mins: "1.5")).not_to be_valid
  end

  it "supprime ses ingrédients avec elle (régression MOD-01)" do
    recipe = create(:recipe_ingredient).recipe

    expect { recipe.destroy! }.to change(RecipeIngredient, :count).by(-1)
  end
end
