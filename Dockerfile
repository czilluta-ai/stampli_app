# Minimal Node image
FROM node:20-alpine
WORKDIR /usr/src/app
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force
COPY app ./app
EXPOSE 3000
ENV PORT=3000
CMD ["node", "app/server.js"]
