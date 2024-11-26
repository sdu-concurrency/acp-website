# Welcome

This is the repo of the ACP Section website!

# Build and run with Docker

On ARM64:

```sh
docker build --pull -f docker/Dockerfile -t acp-website .
docker run -it --rm -p 8080:8080 acp-website
```

On Apple Chipsets:

```sh
docker buildx create --use
docker buildx build --platform linux/amd64 -f docker/Dockerfile -t acp-website --load .
docker run -it --rm -p 8080:8080 acp-website
```

If you make changes to the site, you'll need to re-run the "build" and "run" commands to see your changes.

# Build

```sh
# You need this only once to install dependencies, and then once every time you update dependencies in package.json
npm install

# Run this every time you use new CSS classes in your HTML (it generates an optimised CSS)
npm run build
```

# Launch

```sh
jolie main.ol
# You can just keep it running and update your web files, they will get automatically reloaded
```