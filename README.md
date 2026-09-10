# ShopNow

A small but realistic e-commerce demo application for the **Poly-Orchestrator** DevOps
lab. It runs locally with Docker Compose today and is built to be deployed to
**Amazon ECS Fargate** in a later phase — no AWS-specific code or configuration is
baked in anywhere.

ShopNow is a product catalog with product detail pages and a client-side shopping
cart. No auth, no accounts, no payments, no checkout, no admin dashboard. The
interesting part is the plumbing: a React frontend, a FastAPI backend, PostgreSQL
for persistence, and Redis as a read cache — enough real functionality to make that
plumbing genuinely necessary.

## Features

- Product catalog homepage with a modest hero and a responsive product grid
  (4 columns desktop / 3 tablet / 2 mobile)
- Client-side search that filters the catalog by name/description
- Product detail page (`/products/:id`) loaded live from the backend API
- Quantity selector and Add to Cart on both the catalog and the detail page
- Client-side shopping cart (`/cart`): add, remove, increase/decrease quantity,
  subtotal, item count, empty-cart state — persisted in `localStorage`
- Loading, error, empty, not-found and out-of-stock states throughout
- Local static product images (SVG) so the whole app works fully offline in Docker

## Architecture

```text
                Frontend  (React + Vite, served by nginx)
                   │
                   ▼
              Backend API  (FastAPI + Uvicorn)
                │      │
                ▼      ▼
           PostgreSQL  Redis
```

Request flow for `GET /api/products`:

```text
Frontend
   ↓
Backend
   ↓
Redis
   │
   ├── cache hit  → return cached products
   │
   └── cache miss
          ↓
       PostgreSQL
          ↓
       store in Redis (TTL 60s)
          ↓
       return products
```

In Docker Compose the browser talks to the **frontend** origin, and nginx proxies
`/api/*` and `/health` to the `backend` service by its Compose service name.
That keeps the browser out of the container network and means the same image
works later behind an ALB with ECS Service Connect / Cloud Map — only the
`BACKEND_HOST` environment variable changes.

## Project structure

```text
shopnow/
├── frontend/
│   ├── public/
│   │   ├── favicon.svg
│   │   └── products/            # local static product images (SVG)
│   ├── src/
│   │   ├── App.tsx               # layout + route table
│   │   ├── api.ts                 # fetch helpers, configurable API base URL
│   │   ├── cart/CartContext.tsx   # cart state + localStorage persistence
│   │   ├── components/
│   │   │   ├── Header.tsx         # nav, search, cart icon/count
│   │   │   └── ProductCard.tsx
│   │   ├── pages/
│   │   │   ├── Home.tsx           # hero + product grid + search filter
│   │   │   ├── ProductDetail.tsx  # GET /api/products/{id}
│   │   │   └── Cart.tsx
│   │   ├── index.css              # hand-written CSS, no UI framework
│   │   ├── main.tsx                # router + cart provider
│   │   └── vite-env.d.ts
│   ├── index.html
│   ├── nginx.conf.template     # rendered at container start from env vars
│   ├── package.json
│   ├── tsconfig.json
│   ├── vite.config.ts
│   └── Dockerfile              # multi-stage: node build → nginx runtime
│
├── backend/
│   ├── app/
│   │   ├── main.py             # FastAPI app, endpoints, cache logic
│   │   ├── config.py           # all config from environment variables
│   │   ├── database.py         # engine, session, create tables + seed
│   │   ├── models.py           # Product ORM model
│   │   ├── schemas.py          # Pydantic response models
│   │   └── redis_client.py     # Redis helpers, fail-soft
│   ├── requirements.txt
│   └── Dockerfile
│
├── docker-compose.yml
├── .env.example
├── .gitignore
└── README.md
```

## Technologies

| Tier    | Technology |
|---------|------------|
| Frontend | React 18, React Router, Vite, TypeScript, plain CSS, nginx (runtime) |
| Backend  | Python 3.12, FastAPI, Uvicorn, SQLAlchemy 2.x, psycopg 3, redis-py |
| Database | PostgreSQL 16 (official image) |
| Cache    | Redis 7 (official image) |
| Runtime  | Docker, Docker Compose |

## Product images

Product images are plain SVG files committed under `frontend/public/products/` and
served by nginx alongside the rest of the static build. The backend only stores a
path (`image_url`, e.g. `/products/laptop.svg`); it never generates or proxies
images. This keeps the demo fully self-contained — no external image host, no
image-processing service, and no network dependency at build or run time.

## Running it

```bash
cp .env.example .env
docker compose up --build
```

Then open:

- Frontend: <http://localhost:3000>
- Backend health: <http://localhost:8000/health>
- Products API: <http://localhost:8000/api/products>

Stop it:

```bash
docker compose down          # stop and remove containers
docker compose down -v       # also delete the PostgreSQL volume (fresh seed)
```

Logs:

```bash
docker compose logs -f              # everything
docker compose logs -f backend      # backend only — shows CACHE HIT / CACHE MISS
docker compose ps                   # service + health status
```

## Pages / routes (frontend)

| Route            | Page                                                           |
|-------------------|-----------------------------------------------------------------|
| `/`               | Home — hero + product grid, client-side search over the loaded catalog |
| `/products/:id`   | Product detail — image, price, description, stock, quantity selector, Add to Cart. Data comes from `GET /api/products/{id}`, nothing is hardcoded. |
| `/cart`           | Shopping cart — line items, quantity controls, subtotal, empty-cart state |

React Router handles client-side navigation; nginx falls back unmatched paths to
`index.html` (`try_files … /index.html`) so refreshing `/products/3` or `/cart`
directly still works.

The cart itself is pure frontend state (React context + `localStorage`) — there is
no cart/order table or endpoint on the backend.

## API endpoints

| Method | Path                 | Description |
|--------|----------------------|-------------|
| GET    | `/health`            | `{"status": "healthy"}` — for ECS/ALB health checks |
| GET    | `/api/products`      | All products (Redis-cached, 60s TTL) |
| GET    | `/api/products/{id}` | One product (Redis-cached), `404` if missing |
| GET    | `/healthz`           | Frontend container's own health endpoint (nginx) |

Interactive docs are available at <http://localhost:8000/docs>.

## Database model

One table, `products`:

| Column        | Type          | Notes |
|---------------|---------------|-------|
| `id`          | integer, PK   | |
| `name`        | varchar(120)  | |
| `description` | text          | |
| `price`       | numeric(10,2) | |
| `image_url`   | varchar(255)  | Path to a static image served by the frontend, e.g. `/products/laptop.svg` |
| `in_stock`    | boolean       | Drives the availability badge and disables Add to Cart when false |

## How PostgreSQL is used

- On startup the backend retries the connection for up to ~60 seconds (so a slow
  database start is not fatal), calls `create_all()`, and — only if the table is
  empty — inserts eight sample products: Aurora 14 Laptop, Wireless Mouse,
  Mechanical Keyboard, 27" QHD Monitor, USB-C Hub, Wireless Headphones, HD Webcam,
  and a Portable SSD (seeded as out-of-stock, to demonstrate that state).
- No Alembic. For a single table in a lab app, migrations would be more machinery
  than value.
- Data lives in the `postgres_data` named volume, so it survives `docker compose down`.
  Because the schema gained `image_url` / `in_stock` columns in this revision, a
  volume created by an older version of this app needs `docker compose down -v`
  once before starting the new image (fresh columns need a fresh seed, not a
  migration, in a lab app like this).

## How Redis caching works

- `GET /api/products` looks for the key `shopnow:products:all`; individual products
  use `shopnow:products:{id}`.
- On a miss the backend queries PostgreSQL, writes the JSON payload to Redis with
  a 60-second TTL (`CACHE_TTL_SECONDS`), and returns it.
- Every request logs which path it took:

  ```text
  CACHE MISS -> PostgreSQL (shopnow:products:all)
  Cached shopnow:products:all for 60s
  CACHE HIT  -> Redis (shopnow:products:all)
  ```

- Caching is fail-soft: if Redis is unreachable the backend logs a warning and
  serves from PostgreSQL instead of erroring.

Demo it during the lab:

```bash
curl -s localhost:8000/api/products > /dev/null   # CACHE MISS
curl -s localhost:8000/api/products > /dev/null   # CACHE HIT
docker compose logs backend | grep CACHE
```

## Environment variables

Nothing infrastructure-specific is hard-coded — no `localhost` for PostgreSQL or
Redis anywhere in the backend. That is what lets the same image point at RDS and
ElastiCache later without a code change.

Backend:

| Variable | Local default | Purpose |
|----------|---------------|---------|
| `DATABASE_HOST` | `postgres` | Compose service name → later the RDS endpoint |
| `DATABASE_PORT` | `5432` | |
| `DATABASE_NAME` | `shopnow` | |
| `DATABASE_USER` | `shopnow` | |
| `DATABASE_PASSWORD` | `shopnow_local_dev` | **local development only** |
| `REDIS_HOST` | `redis` | Compose service name → later the ElastiCache endpoint |
| `REDIS_PORT` | `6379` | |
| `REDIS_DB` | `0` | |
| `CACHE_TTL_SECONDS` | `60` | Cache lifetime |
| `CORS_ORIGINS` | `*` | Comma-separated allowed origins |

Frontend:

| Variable | Local default | Purpose |
|----------|---------------|---------|
| `VITE_API_BASE_URL` (build arg) | empty | Empty = same-origin requests proxied by nginx. Set it only if the browser must call the backend directly. |
| `BACKEND_HOST` (runtime) | `backend` | Upstream the nginx proxy forwards to |
| `BACKEND_PORT` (runtime) | `8000` | |
| `FRONTEND_PORT` (runtime) | `80` | Port nginx listens on |
| `DNS_RESOLVER` (runtime) | `127.0.0.11` | Docker embedded DNS; on ECS awsvpc use `169.254.169.253` |

Host port mapping (`.env`): `BACKEND_PORT=8000`, `FRONTEND_HOST_PORT=3000`.

`.env` is gitignored — only `.env.example` is committed, and its credentials are
local-development placeholders.

## Health checks and startup ordering

- `postgres`: `pg_isready`
- `redis`: `redis-cli ping`
- `backend`: HTTP `GET /health` (the same endpoint an ALB target group will use)
- `frontend`: HTTP `GET /healthz`
- `backend` waits for `postgres` and `redis` to report **healthy**; on top of that
  the backend retries the database connection itself, so a few seconds of
  database warm-up never fails the stack.
- nginx resolves the backend name per request (`resolver` + variable `proxy_pass`),
  so restarting the backend does not require restarting the frontend.

## Ready for the next phase

- Both images are stateless and configured purely through environment variables.
- The backend listens on `0.0.0.0:8000` under Uvicorn and runs as a non-root user.
- The frontend ships a static build served by nginx — no dev server in the image.
- `/health` is already the health-check contract for ECS and the ALB.
- Nothing AWS-specific (no Terraform, no task definitions, no Cloud Map) is here yet;
  that comes next.
