package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
)

// Opt-in test of real DynamoDB condition expressions; never starts CodeBuild.
// Each test owns a unique, non-GitLab job key and removes only its own record.
func TestDynamoIntegration(t *testing.T) {
	table := os.Getenv("TIMO_TEST_JOB_TABLE")
	if table == "" {
		t.Skip("set TIMO_TEST_JOB_TABLE for AWS integration verification")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		t.Fatal(err)
	}
	client := dynamodb.NewFromConfig(cfg)
	store := &dynamoJobs{client: client, table: table}
	key := fmt.Sprintf("verification:%d", time.Now().UnixNano())
	var wg sync.WaitGroup
	winners := make(chan string, 20)
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			owner := fmt.Sprintf("verification-%d", i)
			claim, err := store.Claim(ctx, key, owner)
			if err != nil {
				t.Error(err)
				return
			}
			if claim.Acquired {
				winners <- owner
			}
		}(i)
	}
	wg.Wait()
	close(winners)
	owners := []string{}
	for owner := range winners {
		owners = append(owners, owner)
	}
	if len(owners) != 1 {
		t.Fatalf("expected one winner, got %d", len(owners))
	}
	owner := owners[0]
	t.Cleanup(func() {
		cleanupCtx, cleanupCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cleanupCancel()
		_, err := client.DeleteItem(cleanupCtx, &dynamodb.DeleteItemInput{
			TableName: aws.String(table), Key: jobKey(key),
			ConditionExpression:       aws.String("#owner = :owner"),
			ExpressionAttributeNames:  map[string]string{"#owner": "owner"},
			ExpressionAttributeValues: map[string]types.AttributeValue{":owner": stringValue(owner)},
		})
		if err != nil {
			t.Errorf("cleanup: %v", err)
		}
	})
	if err := store.Complete(ctx, key, "wrong-owner", "verification-build"); err == nil {
		t.Fatal("foreign owner changed claim")
	}
	if err := store.Release(ctx, key, "wrong-owner"); err == nil {
		t.Fatal("foreign owner deleted claim")
	}
	if err := store.Release(ctx, key, owner); err != nil {
		t.Fatal(err)
	}
	claim, err := store.Claim(ctx, key, owner)
	if err != nil || !claim.Acquired {
		t.Fatalf("released claim cannot retry: %+v %v", claim, err)
	}
	if err := store.Complete(ctx, key, owner, "verification-build"); err != nil {
		t.Fatal(err)
	}
	claim, err = store.Claim(ctx, key, "late-replay")
	if err != nil || claim.Acquired || claim.BuildID != "verification-build" {
		t.Fatalf("replay not suppressed: %+v %v", claim, err)
	}
	if err := store.Release(ctx, key, owner); err == nil {
		t.Fatal("completed claim was released")
	}
}

// Verify the deployed handler without starting a runner: a synthetic job is
// already marked as dispatched before its pending event is sent.
func TestLambdaIntegrationSuppression(t *testing.T) {
	table, url, secretARN := os.Getenv("TIMO_TEST_JOB_TABLE"), os.Getenv("TIMO_TEST_WEBHOOK_URL"), os.Getenv("TIMO_TEST_SECRET_ARN")
	if table == "" || url == "" || secretARN == "" {
		t.Skip("AWS smoke test environment not provided")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		t.Fatal(err)
	}
	client := dynamodb.NewFromConfig(cfg)
	store := &dynamoJobs{client: client, table: table}
	jobID := time.Now().UnixNano()
	key := fmt.Sprintf("1444183:%d", jobID)
	owner := "lambda-verification"
	claim, err := store.Claim(ctx, key, owner)
	if err != nil || !claim.Acquired {
		t.Fatalf("seed claim: %v", err)
	}
	t.Cleanup(func() {
		cleanupCtx, cleanupCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cleanupCancel()
		_, err := client.DeleteItem(cleanupCtx, &dynamodb.DeleteItemInput{
			TableName: aws.String(table), Key: jobKey(key), ConditionExpression: aws.String("#owner = :owner"),
			ExpressionAttributeNames:  map[string]string{"#owner": "owner"},
			ExpressionAttributeValues: map[string]types.AttributeValue{":owner": stringValue(owner)},
		})
		if err != nil {
			t.Errorf("cleanup: %v", err)
		}
	})
	if err := store.Complete(ctx, key, owner, "verification-only-no-build"); err != nil {
		t.Fatal(err)
	}
	secret, err := secretsmanager.NewFromConfig(cfg).GetSecretValue(ctx, &secretsmanager.GetSecretValueInput{SecretId: aws.String(secretARN)})
	if err != nil || secret == nil || secret.SecretString == nil {
		t.Fatal("cannot load webhook credential")
	}
	for _, tc := range []struct{ status, message string }{{"created", "Ignored event"}, {"pending", "Worker already requested"}, {"pending", "Worker already requested"}} {
		body := fmt.Sprintf(`{"object_kind":"build","project_id":1444183,"build_id":%d,"build_status":%q}`, jobID, tc.status)
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, strings.NewReader(body))
		if err != nil {
			t.Fatal("cannot create verification request")
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Gitlab-Token", *secret.SecretString)
		req.Header.Set("X-Gitlab-Event", "Job Hook")
		req.Header.Set("X-Gitlab-Event-UUID", "lambda-verification")
		resp, err := (&http.Client{Timeout: 10 * time.Second}).Do(req)
		if err != nil {
			t.Fatal("verification HTTP request failed")
		}
		var result struct {
			Message string `json:"message"`
		}
		err = json.NewDecoder(resp.Body).Decode(&result)
		resp.Body.Close()
		if err != nil || resp.StatusCode != 200 || result.Message != tc.message {
			t.Fatalf("%s: status=%d message=%q", tc.status, resp.StatusCode, result.Message)
		}
	}
}
