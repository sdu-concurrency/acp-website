FROM jolielang/jolie:1.13.2-dev AS build
ADD *.ol *.js *.json /work/
COPY data /work/data
COPY templates /work/templates
COPY web /work/web
WORKDIR /work
RUN sudo npm install && sudo npm run build

FROM jolielang/jolie:1.13.2
COPY --from=build /work /app
WORKDIR /app

EXPOSE 8080

CMD ["jolie","main.ol"]
