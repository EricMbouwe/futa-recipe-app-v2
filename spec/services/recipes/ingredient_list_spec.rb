require "rails_helper"

RSpec.describe Recipes::IngredientList do
  it "découpe, normalise, déduplique et ignore les termes vides" do
    expect(described_class.parse("  Rice, BREAD ,, rice , white   rice")).to eq([ "rice", "bread", "white rice" ])
  end

  it "met en minuscules les caractères accentués" do
    expect(described_class.parse("CRÈME Fraîche")).to eq([ "crème fraîche" ])
  end

  it "renvoie une liste vide pour nil ou une chaîne vide" do
    expect(described_class.parse(nil)).to eq([])
    expect(described_class.parse("")).to eq([])
  end
end
