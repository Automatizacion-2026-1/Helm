# Users API Dockerfile (Spring Boot/Java)
FROM maven:3.8-openjdk-8-slim AS builder

WORKDIR /app

# Copiar pom.xml y descargar dependencias
COPY ./pom.xml ./
RUN mvn dependency:go-offline -B

# Copiar el código fuente y compilar
COPY ./src ./src
RUN mvn clean package -DskipTests

# Imagen final
FROM maven:3.8-openjdk-8-slim

WORKDIR /app

COPY --from=builder /app/target/*.jar app.jar

# Variables de entorno por defecto
ENV SERVER_PORT=8083
ENV JWT_SECRET=myfancysecret
ENV SPRING_ZIPKIN_BASEURL=http://127.0.0.1:9411/

EXPOSE 8083

ENTRYPOINT ["java", "-jar", "app.jar"]
