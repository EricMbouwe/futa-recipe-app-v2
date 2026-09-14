module Recipes
  # Charge le jeu de données allrecipes.com. Ne fait rien si des recettes existent déjà.
  class Populator
    DATA_PATH = Rails.root.join("db/data/recipes-en.json")
    BATCH_SIZE = 1_000

    def initialize(path: DATA_PATH, batch_size: BATCH_SIZE)
      @path = path
      @batch_size = batch_size
    end

    # Renvoie le nombre de recettes insérées (0 si la table était déjà remplie).
    def populate
      return 0 if Recipe.exists?

      raw_data.each_slice(@batch_size).sum { |slice| insert(slice) }
    end

    private

    def raw_data
      JSON.parse(File.read(@path))
    end

    def insert(slice)
      recipes = []
      ingredients = []

      slice.each do |data|
        recipe_id = SecureRandom.uuid

        recipes << {
          id: recipe_id,
          name: data.fetch("title"),
          category: data["category"].to_s,
          result_image_url: data.fetch("image"),
          duration_in_mins: data["cook_time"].to_i + data["prep_time"].to_i
        }

        Array(data["ingredients"]).each do |description|
          ingredients << { recipe_id:, ingredient_description: description }
        end
      end

      ActiveRecord::Base.transaction do
        Recipe.insert_all!(recipes)
        RecipeIngredient.insert_all!(ingredients) if ingredients.any?
      end

      recipes.size
    end
  end
end
