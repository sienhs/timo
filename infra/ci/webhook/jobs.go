package main

import (
	"context"
	"errors"
	"strconv"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

type jobClaim struct {
	Acquired bool
	BuildID  string
}

type jobStore interface {
	Claim(context.Context, string, string) (jobClaim, error)
	Complete(context.Context, string, string, string) error
	Release(context.Context, string, string) error
}

type dynamoAPI interface {
	PutItem(context.Context, *dynamodb.PutItemInput, ...func(*dynamodb.Options)) (*dynamodb.PutItemOutput, error)
	GetItem(context.Context, *dynamodb.GetItemInput, ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error)
	UpdateItem(context.Context, *dynamodb.UpdateItemInput, ...func(*dynamodb.Options)) (*dynamodb.UpdateItemOutput, error)
	DeleteItem(context.Context, *dynamodb.DeleteItemInput, ...func(*dynamodb.Options)) (*dynamodb.DeleteItemOutput, error)
}

type dynamoJobs struct {
	client dynamoAPI
	table  string
}

func stringValue(s string) types.AttributeValue { return &types.AttributeValueMemberS{Value: s} }
func jobKey(key string) map[string]types.AttributeValue {
	return map[string]types.AttributeValue{"job_key": stringValue(key)}
}

func (d *dynamoJobs) Claim(ctx context.Context, key, owner string) (jobClaim, error) {
	item := jobKey(key)
	item["owner"] = stringValue(owner)
	item["status"] = stringValue("starting")
	item["created_at"] = &types.AttributeValueMemberN{Value: strconv.FormatInt(time.Now().Unix(), 10)}
	_, err := d.client.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(d.table), Item: item,
		ConditionExpression: aws.String("attribute_not_exists(job_key)"),
	})
	if err == nil {
		return jobClaim{Acquired: true}, nil
	}
	var collision *types.ConditionalCheckFailedException
	if !errors.As(err, &collision) {
		return jobClaim{}, err
	}
	current, err := d.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(d.table), Key: jobKey(key), ConsistentRead: aws.Bool(true),
	})
	if err != nil {
		return jobClaim{}, err
	}
	if current != nil {
		if id, ok := current.Item["build_id"].(*types.AttributeValueMemberS); ok {
			return jobClaim{BuildID: id.Value}, nil
		}
	}
	// Another invocation may still be starting the build or its response may have
	// been lost. Do not expire/take over this record: CodeBuild idempotency expires.
	return jobClaim{}, nil
}

func (d *dynamoJobs) Complete(ctx context.Context, key, owner, buildID string) error {
	_, err := d.client.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName: aws.String(d.table), Key: jobKey(key),
		ConditionExpression:      aws.String("#owner = :owner AND #status = :starting"),
		UpdateExpression:         aws.String("SET #status = :started, build_id = :build"),
		ExpressionAttributeNames: map[string]string{"#owner": "owner", "#status": "status"},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":owner": stringValue(owner), ":starting": stringValue("starting"),
			":started": stringValue("started"), ":build": stringValue(buildID),
		},
	})
	return err
}

func (d *dynamoJobs) Release(ctx context.Context, key, owner string) error {
	_, err := d.client.DeleteItem(ctx, &dynamodb.DeleteItemInput{
		TableName: aws.String(d.table), Key: jobKey(key),
		ConditionExpression:      aws.String("#owner = :owner AND #status = :starting"),
		ExpressionAttributeNames: map[string]string{"#owner": "owner", "#status": "status"},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":owner": stringValue(owner), ":starting": stringValue("starting"),
		},
	})
	return err
}
