class CreateRecipes < ActiveRecord::Migration[6.1]
  def change
    create_table :recipes, id: :uuid do |t|
      t.string :name, null: false
      t.string :category, null: false
      t.integer :duration_in_mins, null: false
      t.string :result_image_url, null: false

      t.timestamps default: -> { 'CURRENT_TIMESTAMP' }
    end
  end
end
