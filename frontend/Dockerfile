FROM node:10-stretch AS build

WORKDIR /app
COPY package*.json ./

# Cambiar repositorios a archive.debian.org y desactivar la validación de fechas
RUN sed -i 's|deb.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid && \
    apt-get update && \
    apt-get install -y python make g++ && \
    npm install

COPY . .

# Build de producción
RUN npm run build

# Etapa de producción con nginx
FROM nginx:alpine

# Copiar archivos build de Vue.js
COPY --from=build /app/dist /usr/share/nginx/html

# Crear directorio para configuración de nginx
RUN mkdir -p /etc/nginx/conf.d

# Exponer puerto
EXPOSE 80

# Comando para iniciar nginx
CMD ["nginx", "-g", "daemon off;"]
