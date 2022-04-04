module Recipes
  class Populator
    def populate
      recipes, recipe_ingredients = prepare_data

      ActiveRecord::Base.transaction do
        Recipe.insert_all(recipes)
        RecipeIngredient.insert_all(recipe_ingredients)
      end

      true
    end

    private

    def file
      File.read('./config/data/recipes-en.json')
    end

    def raw_data
      JSON.parse(file)
    end

    def prepare_data
      recipes = []
      recipe_ingredients = []

      raw_data.each do |data|
        recipe_id = SecureRandom.uuid

        recipes.push(
          id: recipe_id,
          name: data['title'],
          category: data['category'],
          result_image_url: data['image'],
          duration_in_mins: data['cook_time'] + data['prep_time'],
        )

        data['ingredients'].each do |ingredient_description|
          recipe_ingredients.push(
            recipe_id: recipe_id,
            ingredient_description: ingredient_description,
          )
        end
      end

      return recipes, recipe_ingredients
    end
  end
end
