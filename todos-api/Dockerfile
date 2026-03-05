# Todos API Dockerfile (Node.js)
FROM node:14-alpine

WORKDIR /app

COPY ./package*.json ./

RUN npm ci --only=production

COPY . .

ENV TODO_API_PORT=8082
ENV JWT_SECRET=foo
ENV REDIS_HOST=localhost
ENV REDIS_PORT=6379
ENV REDIS_CHANNEL=log_channel

EXPOSE 8082

CMD ["node", "server.js"]
