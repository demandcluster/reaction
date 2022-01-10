# Dockerfile for production builds
FROM reactioncommerce/node-prod:14.18.1-v1

# hadolint ignore=DL3018
RUN apk --no-cache add bash curl less tini vim make python2 git g++ glib
SHELL ["/bin/bash", "-o", "pipefail", "-o", "errexit", "-u", "-c"]

WORKDIR /usr/local/src/app
ENV PATH=$PATH:/usr/local/src/app/node_modules/.bin
# this expires but should still not be here.. working on fix
ARG NPM_ARG=NPM_ARG
ENV NPM_TOKEN=$NPM_ARG
ARG NPM_P=NPM_P
ENV NPM_PASS=$NPM_P
ENV NPM_USER=demandcluster
ENV NPM_EMAIL=devops@demandcluster.com
# Allow yarn/npm to create ./node_modules
RUN chown node:node .

# Install the latest version of NPM (as of when this
# base image is built)
RUN npm i -g npm@latest
RUN npm i -g npm-cli-login@latest
RUN npm set-registry https://npm.demandcluster.com
RUN npm-cli-login

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

COPY --chown=node:node package.json ./
COPY --chown=node:node package-lock.json LICENSE* ./
COPY --chown=node:node ./src ./src
COPY --chown=node:node ./.npmrc ./
RUN chown node:node /usr/local/src/app -R
USER node
#RUN npm set registry https://npm.demandcluster.com

# RUN source ./npm_token
# Install dependencies
RUN npm i --only=prod --no-scripts
# delete npm token
#RUN rm -f .npmrc || :
#RUN rm -f npm_token || :

# The `node-prod` base image installs NPM deps with --no-scripts.
# This prevents the `sharp` lib from working because it installs the binaries
# in a post-install script. We copy their install script here and run it.
# hadolint ignore=DL3003,SC2015
RUN cd node_modules/sharp && (node install/libvips && node install/dll-copy && prebuild-install) || (node-gyp rebuild && node install/dll-copy)

# The base image copies /src but we need to copy additional folders in this project
COPY --chown=node:node ./public ./public
COPY --chown=node:node ./plugins.json ./plugins.json
