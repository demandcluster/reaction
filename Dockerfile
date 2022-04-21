FROM node:16.13-alpine

# hadolint ignore=DL3018
RUN apk --no-cache add bash curl less tini vim make python2 git g++ glib
SHELL ["/bin/bash", "-o", "pipefail", "-o", "errexit", "-u", "-c"]

WORKDIR /usr/local/src/app
ENV PATH=$PATH:/usr/local/src/app/node_modules/.bin

ARG NPM_TOKEN
ENV NPM_TOKEN=$NPM_TOKEN

# Allow yarn/npm to create ./node_modules
RUN chown node:node .

RUN npm i -g is-docker
RUN npm i -g husky

#COPY --chown=node:node ./npm_token ./npm_token
#RUN chmod +x ./npm_token

# Copy specific things so that we can keep the image
# as small as possible without relying on each repo
# to include a .dockerignore file.
#
# Note that there is a reason these are on separate lines.
# COPY command will fail unless at least one file exists
# So we put LICENSE* on the same line as package-lock.json,
# effectively making it optional to have a LICENSE file.
# But the others are on their own line so that the build
# will fail if they are not present in the project.

COPY --chown=node:node package.json .npmrc ./
COPY --chown=node:node package-lock.json LICENSE* ./

RUN chown node:node /usr/local/src/app -R
USER node

RUN npm set registry https://npm.demandcluster.com

# Install dependencies
RUN npm i --only=prod --no-scripts

COPY --chown=node:node ./src ./src

# The base image copies /src but we need to copy additional folders in this project
COPY --chown=node:node ./public ./public
COPY --chown=node:node ./plugins.json ./plugins.json

# If any Node flags are needed, they can be set in
# the NODE_OPTIONS env variable.
#
# NOTE: We would prefer to use `node .` but relying on
# Node to look up the `main` path is currently broken
# when ECMAScript module support is enabled. When this
# is fixed, change command to:
#
# CMD ["tini", "--", "node", "."]
#
CMD ["tini", "--", "npm", "start"]
