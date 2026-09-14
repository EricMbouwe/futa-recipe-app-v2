require "rails_helper"

RSpec.describe V1::Recipes::SearchContract do
  def call(params) = described_class.new.call(params)

  it "accepte des paramètres valides et convertit les entiers" do
    result = call("ingredients" => "rice, crème fraîche, sour-dough, chef's salt", "page" => "2", "count_per_page" => "100")

    expect(result).to be_success
    expect(result.to_h).to eq(ingredients: "rice, crème fraîche, sour-dough, chef's salt", page: 2, count_per_page: 100)
  end

  it "accepte l'absence de paramètres et une liste d'ingrédients vide" do
    expect(call({})).to be_success
    expect(call("ingredients" => "")).to be_success
  end

  it "compte les ingrédients après déduplication" do
    expect(call("ingredients" => ([ "rice" ] * 30).join(","))).to be_success
  end

  {
    { "page" => "0" } => { page: [ "must be greater than or equal to 1" ] },
    { "page" => "-2" } => { page: [ "must be greater than or equal to 1" ] },
    { "page" => "abc" } => { page: [ "must be an integer" ] },
    { "count_per_page" => "0" } => { count_per_page: [ "must be greater than or equal to 1" ] },
    { "count_per_page" => "101" } => { count_per_page: [ "must be less than or equal to 100" ] },
    { "ingredients" => "rice;drop table" } => { ingredients: [ "contains invalid ingredients: rice;drop table" ] },
    { "ingredients" => "rice,r" } => { ingredients: [ "contains invalid ingredients: r" ] },
    { "ingredients" => "egg.*" } => { ingredients: [ "contains invalid ingredients: egg.*" ] },
    { "ingredients" => "-rice" } => { ingredients: [ "contains invalid ingredients: -rice" ] }
  }.each do |params, errors|
    it "rejette #{params.inspect}" do
      expect(call(params).errors.to_h).to eq(errors)
    end
  end

  it "rejette plus de 20 ingrédients distincts" do
    terms = (1..21).map { |n| "ingredient #{n}" }.join(",")

    expect(call("ingredients" => terms).errors.to_h).to eq(ingredients: [ "must contain at most 20 ingredients" ])
  end

  it "tronque la liste des termes invalides renvoyée au client" do
    terms = (1..8).map { |n| "bad;#{n}" }.join(",")

    expect(call("ingredients" => terms).errors.to_h[:ingredients].first)
      .to eq("contains invalid ingredients: bad;1, bad;2, bad;3, bad;4, bad;5")
  end
end
