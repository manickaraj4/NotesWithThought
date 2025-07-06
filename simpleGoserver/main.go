package main

import (
	"os"

	"golang.org/x/net/context"
)

type Post struct {
	ID   int    `json:"id"`
	Body string `json:"body"`
}

type User struct {
	Id    int64  `json:"id"`
	Sub   string `json:"sub"`
	Login string `json:"login"`
}

var (
	domain   = os.Getenv("DOMAIN")
	s3bucket = os.Getenv("S3_BUCKET")
	ctx      context.Context
)

func main() {

	ctx = context.Background()
	awsInit()
	ssmClientInit()
	databaseInit()
	s3Init()
	googleInit()
	githubInit()
	webServerInit()

}
