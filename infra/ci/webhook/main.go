package main

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-lambda-go/lambdacontext"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/codebuild"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	"github.com/aws/smithy-go"
)

type secretsAPI interface {
	GetSecretValue(context.Context, *secretsmanager.GetSecretValueInput, ...func(*secretsmanager.Options)) (*secretsmanager.GetSecretValueOutput, error)
}

type buildsAPI interface {
	StartBuild(context.Context, *codebuild.StartBuildInput, ...func(*codebuild.Options)) (*codebuild.StartBuildOutput, error)
}

type handler struct {
	secrets   secretsAPI
	builds    buildsAPI
	jobs      jobStore
	secretARN string
	projectID string
	project   string
	enabled   bool
}

type jobEvent struct {
	Kind      string          `json:"object_kind"`
	Status    string          `json:"build_status"`
	ProjectID json.RawMessage `json:"project_id"`
	JobID     json.RawMessage `json:"build_id"`
}

func main() {
	cfg, err := config.LoadDefaultConfig(context.Background(),
		config.WithHTTPClient(&http.Client{Timeout: 3 * time.Second}),
		config.WithRetryMaxAttempts(1),
	)
	if err != nil {
		log.Fatal("Unable to initialize AWS SDK")
	}
	h := handler{
		secrets: secretsmanager.NewFromConfig(cfg), builds: codebuild.NewFromConfig(cfg),
		jobs:      &dynamoJobs{client: dynamodb.NewFromConfig(cfg), table: os.Getenv("JOB_TABLE")},
		secretARN: os.Getenv("WEBHOOK_SECRET_ARN"), projectID: os.Getenv("GITLAB_PROJECT_ID"),
		project: os.Getenv("CODEBUILD_PROJECT"), enabled: os.Getenv("WEBHOOK_ENABLED") == "true",
	}
	if h.secretARN == "" || h.project == "" || os.Getenv("JOB_TABLE") == "" || positiveID(json.RawMessage(h.projectID)) == "" {
		log.Fatal("Missing or invalid Lambda environment configuration")
	}
	lambda.Start(h.Handle)
}

func respond(status int, message string) (events.LambdaFunctionURLResponse, error) {
	body, _ := json.Marshal(map[string]string{"message": message})
	return events.LambdaFunctionURLResponse{
		StatusCode: status, Headers: map[string]string{"content-type": "application/json"}, Body: string(body),
	}, nil
}

// Reject strings, booleans, fractions and exponent notation for a job ID.
func positiveID(raw json.RawMessage) string {
	s := strings.TrimSpace(string(raw))
	if s == "" {
		return ""
	}
	for _, c := range s {
		if c < '0' || c > '9' {
			return ""
		}
	}
	n, err := strconv.ParseUint(s, 10, 64)
	if err != nil || n == 0 {
		return ""
	}
	return strconv.FormatUint(n, 10)
}

func (h handler) Handle(ctx context.Context, event events.LambdaFunctionURLRequest) (events.LambdaFunctionURLResponse, error) {
	if event.RequestContext.HTTP.Method != http.MethodPost {
		return respond(405, "POST required")
	}
	if !h.enabled {
		return respond(503, "Webhook disabled until setup completes")
	}
	headers := make(map[string]string, len(event.Headers))
	for key, value := range event.Headers {
		headers[strings.ToLower(key)] = value
	}
	supplied := headers["x-gitlab-token"]
	if supplied == "" {
		return respond(401, "Invalid webhook token")
	}
	secret, err := h.secrets.GetSecretValue(ctx, &secretsmanager.GetSecretValueInput{SecretId: aws.String(h.secretARN)})
	if err != nil || secret == nil || secret.SecretString == nil {
		log.Print("Unable to load webhook secret")
		return respond(503, "Webhook authentication unavailable")
	}
	if *secret.SecretString == "" || !hmac.Equal([]byte(supplied), []byte(*secret.SecretString)) {
		return respond(401, "Invalid webhook token")
	}
	if headers["x-gitlab-event"] != "Job Hook" {
		return respond(200, "Ignored event")
	}
	if len(event.Body) > 131072 {
		return respond(413, "Payload too large")
	}
	raw := []byte(event.Body)
	if event.IsBase64Encoded {
		raw, err = base64.StdEncoding.Strict().DecodeString(event.Body)
		if err != nil {
			return respond(400, "Invalid JSON body")
		}
	}
	var payload *jobEvent
	if err := json.Unmarshal(raw, &payload); err != nil || payload == nil {
		return respond(400, "Invalid JSON body")
	}
	requestID := event.RequestContext.RequestID
	if lc, ok := lambdacontext.FromContext(ctx); ok {
		requestID = lc.AwsRequestID
	}
	jobID := positiveID(payload.JobID)
	trace := func(action, buildID, errorCode string) {
		// Structured allowlisted fields only: never log headers, tokens, or the payload.
		entry, _ := json.Marshal(map[string]string{
			"action": action, "request_id": requestID, "event_uuid": headers["x-gitlab-event-uuid"],
			"webhook_uuid": headers["x-gitlab-webhook-uuid"], "job_id": jobID,
			"project_id": positiveID(payload.ProjectID), "job_status": payload.Status,
			"build_id": buildID, "error_code": errorCode,
		})
		log.Print(string(entry))
	}
	// created jobs can still be waiting for earlier stages; only pending needs a worker.
	if payload.Kind != "build" || payload.Status != "pending" || positiveID(payload.ProjectID) != h.projectID {
		trace("ignored", "", "")
		return respond(200, "Ignored event")
	}
	if jobID == "" {
		return respond(400, "Positive build_id required")
	}

	key := h.projectID + ":" + jobID
	claim, err := h.jobs.Claim(ctx, key, requestID)
	if err != nil {
		trace("claim_failed", "", awsErrorCode(err))
		return respond(503, "Worker claim unavailable; retry this delivery")
	}
	if !claim.Acquired {
		if claim.BuildID != "" {
			trace("duplicate", claim.BuildID, "")
			return respond(200, "Worker already requested")
		}
		trace("in_flight_or_uncertain", "", "")
		return respond(503, "Worker request in progress or uncertain; inspect logs before retrying")
	}
	// DynamoDB serializes duplicates, including replays after CodeBuild's five-minute window.
	// The runner still receives any matching pending job, not necessarily this event's job.
	digest := sha256.Sum256([]byte(key))
	trace("start_requested", "", "")
	out, err := h.builds.StartBuild(ctx, &codebuild.StartBuildInput{
		ProjectName: aws.String(h.project), IdempotencyToken: aws.String(hex.EncodeToString(digest[:])),
	})
	if err != nil {
		code := awsErrorCode(err)
		// Only known pre-start rejections release the claim. A timeout/5xx may hide a
		// successful start: retain the claim rather than risk an extra worker.
		if definitelyRejected(code) {
			if releaseErr := h.jobs.Release(ctx, key, requestID); releaseErr != nil {
				trace("release_failed", "", awsErrorCode(releaseErr))
			}
		}
		trace("start_failed", "", code)
		return respond(503, "CodeBuild start failed; retry this delivery")
	}
	if out == nil || out.Build == nil || aws.ToString(out.Build.Id) == "" {
		trace("start_uncertain", "", "MissingBuildID")
		return respond(503, "Missing build result; inspect logs")
	}
	buildID := aws.ToString(out.Build.Id)
	trace("start_succeeded", buildID, "")
	if err := h.jobs.Complete(ctx, key, requestID, buildID); err != nil {
		trace("record_failed", buildID, awsErrorCode(err))
		return respond(503, "Worker started but record update failed; inspect logs")
	}
	return respond(200, "Worker requested")
}

func awsErrorCode(err error) string {
	var apiErr smithy.APIError
	if errors.As(err, &apiErr) {
		return apiErr.ErrorCode()
	}
	return "TransportOrContextError"
}

func definitelyRejected(code string) bool {
	switch code {
	case "AccountLimitExceededException", "InvalidInputException", "ResourceNotFoundException", "AccessDeniedException", "ThrottlingException":
		return true
	default:
		return false
	}
}
