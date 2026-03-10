FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES="jq"
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# ─────────────────────────────────────────────────────────────
# Bake external binaries (must happen before USER node)
# ─────────────────────────────────────────────────────────────
# Twitter/X CLI (bird) - https://github.com/steipete/bird
RUN npm install -g @steipete/bird

# Summarize skill
RUN npm install -g @steipete/summarize

# Gmail CLI (gog) - https://github.com/steipete/gogcli
RUN curl -L https://github.com/steipete/gogcli/releases/download/v0.9.0/gogcli_0.9.0_linux_amd64.tar.gz \
| tar -xz -C /usr/local/bin gog && chmod +x /usr/local/bin/gog

# GitHub CLI (gh) - https://cli.github.com/
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
	apt-get update && \
	apt-get install -y gh && \
	rm -rf /var/lib/apt/lists/*

# Google Workspace CLI (gws) - https://github.com/googleworkspace/cli
RUN npm install -g @googleworkspace/cli

# uv (Python package runner) - for nano-banana-pro and other Python skills
RUN curl -LsSf https://astral.sh/uv/install.sh | env INSTALLER_NO_MODIFY_PATH=1 sh && \
	mv /root/.local/bin/uv /usr/local/bin/ && \
	mv /root/.local/bin/uvx /usr/local/bin/


# ─────────────────────────────────────────────────────────────

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# Security hardening: Run as non-root user
# The node:22-bookworm image includes a 'node' user (uid 1000)
# This reduces the attack surface by preventing container escape via root privileges
USER node

CMD ["node", "dist/index.js"]
