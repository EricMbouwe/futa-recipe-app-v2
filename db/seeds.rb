inserted = Recipes::Populator.new.populate
puts(inserted.zero? ? "Recettes déjà chargées : rien à faire." : "#{inserted} recettes chargées.")
