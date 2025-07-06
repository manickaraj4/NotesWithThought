package main

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/service/ssm"
)

var (
	ssmClient *ssm.Client
)

func ssmClientInit() {

	ssmClient = ssm.NewFromConfig(awscfg)
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
