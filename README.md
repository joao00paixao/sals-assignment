# sals-assignment
 Repository for Sample Application infrastructure and documentation.

## Building and Running with Docker Compose

1. Clone this repository.
2. Run `docker compose build` to build the application.
3. Run `docker compose up` to start the application and database.
4. The application will be available at `http://localhost:4567`.

## Building and Running with Docker

1. Clone this repository.
2. Create a Docker network: `docker network create sals-network`
3. Run `docker run --name db --network sals-network -e POSTGRES_DB=gifmachine -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres` to start the postgres container.
4. Run `docker build -t sals-assignment .` to build the application.
5. Run `docker run --name sals-assignment-container -p 4567:4567 -e POSTGRES_PASSWORD=postgres -e DATABASE_URL=postgres://postgres:postgres@db:5432/gifmachine -e GIFMACHINE_PASSWORD=foo -e RACK_ENV=development --network sals-network sals-assignment` to start the application.
6. The application will be available at `http://localhost:4567`.

