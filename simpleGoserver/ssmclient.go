package main

import (
	"context"
	"fmt"
	"log"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
)

var (
	ssmClient *ssm.Client
)

func ssmClientInit() {

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}

	ssmClient = ssm.NewFromConfig(cfg)
}

func ssmFetchParam(paramName string, withDecryption bool) (string, error) {
	res := ""
	input := &ssm.GetParameterInput{
		Name:           &paramName,
		WithDecryption: &withDecryption,
	}

	result, err := ssmClient.GetParameter(context.TODO(), input)
	if err != nil {
		return res, err
	}

	if result.Parameter != nil {
		res = *result.Parameter.Value
		return res, nil
	} else {
		fmt.Println("Parameter not found.")
		return res, &CustomError{Code: 1, Message: fmt.Sprintf("Error: Parameter %s Not found", paramName)}
	}

}
