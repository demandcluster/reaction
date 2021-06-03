FROM node:14.15.0-alpine

# hadolint ignore=DL3018
RUN apk --no-cache add bash curl less tini vim make python2 git g++ glib
SHELL ["/bin/bash", "-o", "pipefail", "-o", "errexit", "-u", "-c"]

WORKDIR /usr/local/src/app
ENV PATH=$PATH:/usr/local/src/app/node_modules/.bin

# Allow yarn/npm to create ./node_modules
RUN chown node:node .

# Install the latest version of NPM (as of when this
# base image is built)
RUN npm i -g npm@latest

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
ONBUILD ARG NPM_TOKEN
ONBUILD COPY --chown=node:node package.json ./
ONBUILD COPY --chown=node:node package-lock.json .npmrc* LICENSE* ./
ONBUILD COPY --chown=node:node ./src ./src

USER node

# Install dependencies
ONBUILD RUN npm ci --only=prod --ignore-scripts
# delete npm token
ONBUILD RUN rm -f .npmrc || :



ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/lib/node_modules/npm/bin/node-gyp-bin:/usr/local/src/app/node_modules/.bin

# The `node-prod` base image installs NPM deps with --no-scripts.
# This prevents the `sharp` lib from working because it installs the binaries
# in a post-install script. We copy their install script here and run it.
# hadolint ignore=DL3003,SC2015
RUN cd node_modules/sharp && (node install/libvips && node install/dll-copy && prebuild-install) || (node-gyp rebuild && node install/dll-copy)

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

