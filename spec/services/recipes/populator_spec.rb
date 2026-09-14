require "rails_helper"

RSpec.describe Recipes::Populator do
  let(:path) { Rails.root.join("spec/fixtures/files/recipes-sample.json") }

  it "insère recettes et ingrédients par lots" do
    inserted = described_class.new(path:, batch_size: 2).populate

    expect(inserted).to eq(3)
    expect(Recipe.count).to eq(3)
    expect(RecipeIngredient.count).to eq(3)
  end

  it "additionne les durées, tolère une durée absente et conserve une catégorie vide" do
    described_class.new(path:).populate

    expect(Recipe.order(:name).pluck(:name, :duration_in_mins, :category)).to eq([
      [ "Golden Sweet Cornbread", 35, "Cornbread" ],
      [ "Monkey Bread I", 50, "" ],
      [ "Overnight Oats", 5, "Breakfast" ]
    ])
  end

  it "est idempotent (régression MOD-02)" do
    described_class.new(path:).populate

    expect { expect(described_class.new(path:).populate).to eq(0) }.not_to change(Recipe, :count)
  end

  it "lit le jeu de données depuis Rails.root, indépendamment du répertoire courant" do
    expect(described_class::DATA_PATH).to eq(Rails.root.join("db/data/recipes-en.json"))
    expect(File).to exist(described_class::DATA_PATH)
  end
end
