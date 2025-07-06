package main

import (
	"context"
	"io"

	"github.com/aws/aws-sdk-go-v2/service/s3"
)

var (
	s3Client *s3.Client
)

func s3Init() {
	s3Client = s3.NewFromConfig(awscfg)
}

func uploadObject(fileName string, body io.Reader) (bool, error) {
	key := "postsapp/images/" + fileName
	input := &s3.PutObjectInput{
		Bucket:            &s3bucket,
		Key:               &key,
		Body:              body,
		ChecksumAlgorithm: "CRC32",
	}

	result, err := s3Client.PutObject(context.TODO(), input)
	if err != nil {
		return false, err
	}

	if result.ChecksumCRC32 != nil {
		return true, nil
	} else {
		return false, &CustomError{Code: 1, Message: "Checksum not found"}
	}
}

func downloadObject(fileName string) (io.Reader, error) {
	key := "postsapp/images/" + fileName
	input := &s3.GetObjectInput{
		Bucket: &s3bucket,
		Key:    &key,
	}

	result, err := s3Client.GetObject(context.TODO(), input)
	if err != nil {
		return nil, err
	}

	if result.ChecksumCRC32 != nil {
		return result.Body, nil
	} else {
		return nil, &CustomError{Code: 1, Message: "Checksum not found"}
	}
}
