FROM golang:1.24

WORKDIR /usr/src/app

COPY go.mod main.go /usr/src/app

RUN go get github.com/coreos/go-oidc/v3/oidc
RUN go get golang.org/x/net/context
RUN go get golang.org/x/oauth2

RUN go build -v -o /usr/local/bin/app 

CMD ["app"]
