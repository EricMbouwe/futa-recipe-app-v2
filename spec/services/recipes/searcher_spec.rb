require 'rails_helper'

describe Recipes::Searcher do
  let(:searcher) do
    Recipes::Searcher.new(
      ingredients: ingredients,
      page: page,
      count_per_page: count_per_page,
    )
  end

  let(:page) { nil }
  let(:count_per_page) { nil }
  let(:ingredients) do
    [
     "bread",
     "rice"
    ]
  end

  let!(:recipe_1) do
    create(:recipe, name: 'recipe_1').tap do |recipe|
      ['1/2 cup of rice', 'half bread', '1 cup water'].each do |ing_desc|
        create(
          :recipe_ingredient,
          recipe: recipe,
          ingredient_description: ing_desc,
        )
      end
    end
  end

  let!(:recipe_2) do
    create(:recipe, name: 'recipe_1').tap do |recipe|
      ['1/2 cup of rice', '1 cup water'].each do |ing_desc|
        create(
          :recipe_ingredient,
          recipe: recipe,
          ingredient_description: ing_desc,
        )
      end
    end
  end

  describe '#search' do
    it "returns recipes in right order, page, total_count" do
      recipes, res_page, total_count = searcher.search

      expect(res_page).to eq(1)
      expect(total_count).to eq(2)
      expect(recipes.first.id).to eq(recipe_1.id)
      expect(recipes.last.id).to eq(recipe_2.id)
    end

    context "when page and count_per_page provided" do
      let(:page) { 2 }
      let(:count_per_page) { 1 }

      it "returns recipes in right page" do
        recipes, res_page, total_count = searcher.search

        expect(res_page).to eq(2)
        expect(total_count).to eq(2)
        expect(recipes.count).to eq(1)
        expect(recipes.first.id).to eq(recipe_2.id)
      end
    end

    context "when page provided is beyong total recipes found" do
      let(:page) { 3 }
      let(:count_per_page) { 1 }

      it "no recipes is returned" do
        recipes, res_page, total_count = searcher.search

        expect(res_page).to eq(3)
        expect(total_count).to eq(2)
        expect(recipes.empty?).to eq(true)
      end
    end

    context "when no recipes for ingredients provided" do
      let(:ingredients) do
        [
         "milk",
         "sugar"
        ]
      end

      it "no recipes is returned" do
        recipes, res_page, total_count = searcher.search

        expect(res_page).to eq(1)
        expect(total_count).to eq(0)
        expect(recipes.empty?).to eq(true)
      end
    end
  end
end
