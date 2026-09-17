FROM node:20-alpine

# The Firestore and Storage emulators are JVM-based under the hood.
RUN apk add --no-cache openjdk21-jre-headless

RUN npm install -g firebase-tools

WORKDIR /workspace

EXPOSE 4000 5001 8080 9099 9199

ENTRYPOINT ["firebase"]
