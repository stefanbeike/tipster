FROM node:20-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund \
    --fetch-retries=5 \
    --fetch-retry-factor=2 \
    --fetch-retry-mintimeout=20000 \
    --fetch-retry-maxtimeout=120000

COPY . .
ARG VITE_USER_API_URL=http://localhost:8081
ARG VITE_PAYMENT_API_URL=http://localhost:8082
ENV VITE_USER_API_URL=${VITE_USER_API_URL}
ENV VITE_PAYMENT_API_URL=${VITE_PAYMENT_API_URL}
RUN npm run build

FROM nginx:1.27-alpine AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80
HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1
