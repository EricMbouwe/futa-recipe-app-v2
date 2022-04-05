import React, { useState } from 'react';
import ReactPaginate from 'react-paginate';
import "./App.css";

const Recipe = (props) => {
  return (
    <div style={{ padding: '20' }}>
      <h4>{props.name}</h4>
      <img src={props.image_url} width={250} height={250} alt="final result" />
      <div>
        <b>Time:</b> <span>{props.time} mins</span><br/>
        <b>Category:</b> <span>{props.category}</span><br/>
        <b>Ingredients:</b>
        <ul>
          {props.ingredients.map((ing) =><li key={ing} >{ing}</li>)}
        </ul>
      </div>
    </div>
  );
};

const BASE_API_URL = "https://pennylane-recipes-new-api.herokuapp.com"

function App() {
    const [recipes, setRecipes] = useState([]);
    const [page, setPage] = useState(1);
    const [ingredients, setIngredients] = useState([]);
    const [ingredientInput, setIngredientInput] = useState('');

    const handleSearchReceipes = () => {
      let search_query = ingredients.join(',')
      let url = `${BASE_API_URL}/v1/recipes/search?ingredients=${search_query}&page=${page}&count_per_page=20`;

      fetch(url)
        .then(response => response.json())
        .then(body => {
          setRecipes(body.recipes);
        })
        .catch(error => console.error('Error', error));
    }

    const handlePageChange = (selectedObject) => {
      setPage(selectedObject.selected);
      handleSearchReceipes();
    }

    const handleAddIngredient = () => {
      setIngredients([...ingredients, ingredientInput]);
      setIngredientInput('');
    }

    const handleInputChange = (event) => setIngredientInput(event.target.value);

    const handleClear = () => {
      setIngredientInput('');
      setIngredients([]);
      setRecipes([]);
    }

    return (
        <div>
            <div>
              <h1> Pennylane Recipes Finder</h1>
              <p>
                <b>Hey you, welcome!</b>
                <br/>
                We are here help you find what is the best meal you make with the ingredients you have
              </p>
            </div>
            <div>
              <h2>What ingredients do you have</h2>
              <p>
                Please, add 1 by 1 the ingredients you have.
              </p>
              <input type="text" onChange={handleInputChange} />
              &nbsp; &nbsp;
              <button onClick={handleAddIngredient}>Add</button>
            </div>
            <div>
              <h3>Your ingredients</h3>
              {
                ingredients.length > 0 ? (
                  <ul>
                    {ingredients.map((ing) =><li key={ing} >{ing}</li>)}
                  </ul>
                ) : (
                  <div></div>
                )
              }
            </div>
            <button onClick={handleSearchReceipes}>Recommend Recipes </button>
            &nbsp; &nbsp;
            <button onClick={handleClear}>Reset</button>
            <div>
              <h2>Recommended recipes</h2>
              {recipes.length > 0 ? (
                recipes.map((item) => {
                  return (
                    <Recipe
                      name={item.name}
                      time={item.duration_in_mins}
                      category={item.category}
                      ingredients={item.ingredients}
                      image_url={item.result_image_url}
                      key={item.id}
                    />
                  );
                })
              ) : (
                <div></div>
              )}
              {recipes.length > 0 ? (
                <ReactPaginate
                  pageCount={10}
                  pageRange={2}
                  marginPagesDisplayed={2}
                  onPageChange={handlePageChange}
                  containerClassName={'container'}
                  previousLinkClassName={'page'}
                  breakClassName={'page'}
                  nextLinkClassName={'page'}
                  pageClassName={'page'}
                  disabledClassName={'disabled'}
                  activeClassName={'active'}
                />
              ) : (
                <div>Nothing to display</div>
              )}
            </div>
        </div>
    );
}

export default App;
