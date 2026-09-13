require "rails_helper"

RSpec.describe Recipes::Searcher do
  def recipe_with(*descriptions, name: "Recipe")
    create(:recipe, name:).tap do |recipe|
      descriptions.each { |description| create(:recipe_ingredient, recipe:, ingredient_description: description) }
    end
  end

  def search(ingredients, page: nil, count_per_page: nil)
    described_class.new(ingredients:, page:, count_per_page:).search
  end

  describe "#search" do
    let!(:rice_and_bread) { recipe_with("1/2 cup of rice", "half bread", "1 cup water") }
    let!(:rice_only) { recipe_with("1/2 cup of rice", "1 cup water") }

    it "classe les recettes par nombre d'ingrédients trouvés" do
      recipes, page, total_count = search([ "bread", "rice" ])

      expect(page).to eq(1)
      expect(total_count).to eq(2)
      expect(recipes).to eq([ rice_and_bread, rice_only ])
    end

    it "ne compte qu'une fois un terme présent dans plusieurs lignes de la même recette" do
      double_rice = recipe_with("1 cup white rice", "1 cup brown rice")

      recipes, = search([ "rice", "bread" ])

      expect(recipes.first).to eq(rice_and_bread)
      expect(recipes).to include(double_rice)
    end

    it "pagine" do
      recipes, page, total_count = search([ "bread", "rice" ], page: 2, count_per_page: 1)

      expect([ recipes, page, total_count ]).to eq([ [ rice_only ], 2, 2 ])
    end

    it "renvoie une page vide au-delà des résultats" do
      recipes, page, total_count = search([ "bread", "rice" ], page: 3, count_per_page: 1)

      expect([ recipes, page, total_count ]).to eq([ [], 3, 2 ])
    end

    it "renvoie un résultat vide sans correspondance" do
      expect(search([ "milk", "sugar" ])).to eq([ [], 1, 0 ])
    end

    it "renvoie un résultat vide sans terme, sans interroger la base" do
      expect(RecipeIngredient).not_to receive(:where)

      expect(search([])).to eq([ [], 1, 0 ])
    end

    it "précharge les ingrédients des recettes renvoyées" do
      recipes, = search([ "rice" ])

      expect(recipes.map { |recipe| recipe.association(:recipe_ingredients).loaded? }.uniq).to eq([ true ])
    end
  end

  describe "ordre à score égal (régression PERF-02)" do
    it "départage par identifiant et parcourt chaque recette exactement une fois" do
      tied = Array.new(5) { |n| recipe_with("#{n + 1} eggs", name: "Tie #{n}") }

      pages = (1..5).flat_map { |page| search([ "egg" ], page:, count_per_page: 1).first }

      expect(pages.map(&:id)).to eq(tied.map(&:id).sort)
      expect(search([ "egg" ], page: 1, count_per_page: 5).first).to eq(search([ "egg" ], page: 1, count_per_page: 5).first)
    end
  end

  describe "correspondance par mot entier (régression PERF-03)" do
    {
      "egg"    => { matches: [ "2 large eggs", "1 egg", "EGG yolk" ], rejects: [ "1 eggplant, cubed" ] },
      "rice"   => { matches: [ "1 cup white rice" ], rejects: [ "2 ounces licorice" ] },
      "ice"    => { matches: [ "1 cup crushed ice" ], rejects: [ "1 cup rice", "juice of 1 lemon" ] },
      "tomato" => { matches: [ "3 tomatoes, diced", "1 tomato" ], rejects: [ "tomatillo salsa" ] },
      "berry"  => { matches: [ "1 cup berries", "1 berry" ], rejects: [ "1 cup blueberries" ] },
      "eggs"   => { matches: [ "1 egg" ], rejects: [] },
      "white rice" => { matches: [ "2 cups white rice" ], rejects: [ "1 cup rice, white or brown" ] }
    }.each do |term, cases|
      it "« #{term} » trouve #{cases[:matches].inspect} et ignore #{cases[:rejects].inspect}" do
        expected = cases[:matches].map { |description| recipe_with(description) }
        cases[:rejects].each { |description| recipe_with(description) }

        recipes, = search([ term ])

        expect(recipes).to match_array(expected)
      end
    end
  end

  describe ".pattern_for" do
    it "échappe les métacaractères en défense en profondeur" do
      expect(described_class.pattern_for("a.b")).to eq('\ma\.b(s|es)?\M')
    end

    it "gère le pluriel en -ies" do
      expect(described_class.pattern_for("berries")).to eq('\mberr(y|ies)\M')
    end
  end
end
