FROM node:18-alpine AS build

WORKDIR /usr/src/app/ui

COPY ui/ /usr/src/app/ui/

RUN npm install
RUN npm run build

FROM golang:1.24

WORKDIR /usr/src/app

COPY go.mod main.go /usr/src/app/
COPY --from=build /usr/src/app/ui/ /usr/src/app/ui/

RUN go get github.com/coreos/go-oidc/v3/oidc
RUN go get golang.org/x/net/context
RUN go get golang.org/x/oauth2
RUN go get github.com/alexedwards/scs/v2

RUN go build -v -o /usr/local/bin/app 

CMD ["app"]


