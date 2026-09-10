# ---------- build stage ----------
FROM node:20-alpine AS build

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

COPY . .

# Empty by default => the app makes same-origin requests that nginx proxies.
ARG VITE_API_BASE_URL=""
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
RUN npm run build

# ---------- runtime stage ----------
FROM nginx:1.27-alpine

# No dev server in the final image: nginx serves the static build.
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

ENV FRONTEND_PORT=80 \
    BACKEND_HOST=backend \
    BACKEND_PORT=8000 \
    DNS_RESOLVER=127.0.0.11

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
