# Pennylane bank

## API
This work  supports docker with docker-compose for development, so no need to install any stack at all.

It also uses a Makefile in order to save us from typing `docker-compose run bla`

Makefile includes targets for the most common commands needed as:
 - `run`: It starts the Rails server
 - `console` or `c`: It starts the Rails console
 - `migrate` or `dbmigrate`: It runs the migrations
 - `run-docs`: It runs API docs on `http://localhost:8080`

## API Documentation

This repo contains the `open-api v3` documentation for Pennylane bank API.

It is prepared to run it on docker locally using redoc, a visualization tool
for documentation.

For more information about redoc, please visit https://github.com/Rebilly/ReDoc

## Database data
Demo data are provided from [www.allrecipes.com](www.allrecipes.com)

