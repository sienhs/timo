package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"reflect"
	"strings"
	"sync"
	"testing"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/codebuild"
	buildtypes "github.com/aws/aws-sdk-go-v2/service/codebuild/types"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	"github.com/aws/smithy-go"
)

type fakeSecrets struct {
	mu    sync.Mutex
	value *string
	err   error
	calls int
}

func (f *fakeSecrets) GetSecretValue(ctx context.Context, in *secretsmanager.GetSecretValueInput, _ ...func(*secretsmanager.Options)) (*secretsmanager.GetSecretValueOutput, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls++
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	return &secretsmanager.GetSecretValueOutput{SecretString: f.value}, f.err
}

type fakeBuilds struct {
	mu     sync.Mutex
	inputs []*codebuild.StartBuildInput
	err    error
}

func (f *fakeBuilds) StartBuild(ctx context.Context, in *codebuild.StartBuildInput, _ ...func(*codebuild.Options)) (*codebuild.StartBuildOutput, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.inputs = append(f.inputs, in)
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	return &codebuild.StartBuildOutput{Build: &buildtypes.Build{Id: aws.String("timo-gitlab-runner:test-build")}}, f.err
}

type memoryJobs struct {
	mu          sync.Mutex
	items       map[string]string
	completeErr error
}

func (m *memoryJobs) Claim(_ context.Context, key, owner string) (jobClaim, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if id, ok := m.items[key]; ok {
		return jobClaim{BuildID: id}, nil
	}
	m.items[key] = ""
	return jobClaim{Acquired: true}, nil
}
func (m *memoryJobs) Complete(_ context.Context, key, owner, id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.completeErr != nil {
		return m.completeErr
	}
	m.items[key] = id
	return nil
}
func (m *memoryJobs) Release(_ context.Context, key, owner string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.items, key)
	return nil
}

func setup() (handler, *fakeSecrets, *fakeBuilds, events.LambdaFunctionURLRequest) {
	s := &fakeSecrets{value: aws.String("test-secret")}
	b := &fakeBuilds{}
	h := handler{secrets: s, builds: b, jobs: &memoryJobs{items: map[string]string{}}, secretARN: "secret-arn", projectID: "1444183", project: "timo-gitlab-runner", enabled: true}
	var req events.LambdaFunctionURLRequest
	// A Function URL v2 envelope, including the exact requestContext shape Lambda sends.
	if err := json.Unmarshal([]byte(`{
		"requestContext":{"http":{"method":"POST"}},
		"headers":{"X-Gitlab-Token":"test-secret","X-Gitlab-Event":"Job Hook"}
	}`), &req); err != nil {
		panic(err)
	}
	req.Body = `{"object_kind":"build","project_id":1444183,"build_id":123,"build_status":"pending"}`
	return h, s, b, req
}

func checkStatus(t *testing.T, h handler, req events.LambdaFunctionURLRequest, status int) {
	t.Helper()
	got, err := h.Handle(context.Background(), req)
	if err != nil || got.StatusCode != status {
		t.Fatalf("status=%d, err=%v, want=%d; response=%s", got.StatusCode, err, status, got.Body)
	}
	if got.Headers["content-type"] != "application/json" || !json.Valid([]byte(got.Body)) {
		t.Fatal("response is not JSON")
	}
}

func TestPendingJobCannotOverrideCodeBuildSettings(t *testing.T) {
	h, _, b, req := setup()
	req.Body = strings.TrimSuffix(req.Body, "}") + `,"projectName":"attacker","buildspecOverride":"untrusted","environmentVariablesOverride":[{"name":"RUNNER_TOKEN","value":"attacker"}]}`
	checkStatus(t, h, req, 200)
	if len(b.inputs) != 1 {
		t.Fatalf("starts=%d", len(b.inputs))
	}
	got := b.inputs[0]
	want := &codebuild.StartBuildInput{ProjectName: aws.String("timo-gitlab-runner"), IdempotencyToken: got.IdempotencyToken}
	if !reflect.DeepEqual(got, want) || len(aws.ToString(got.IdempotencyToken)) != 64 {
		t.Fatal("unexpected CodeBuild parameters")
	}
}

func TestDuplicateJobStartsOnlyOnceAndDifferentJobStillStarts(t *testing.T) {
	h, _, b, req := setup()
	checkStatus(t, h, req, 200)
	checkStatus(t, h, req, 200)
	req.Body = strings.Replace(req.Body, `"build_id":123`, `"build_id":124`, 1)
	checkStatus(t, h, req, 200)
	if len(b.inputs) != 2 || reflect.DeepEqual(b.inputs[0], b.inputs[1]) {
		t.Fatal("duplicate was started or different job was suppressed")
	}
}

func TestBase64AndLowercaseHeaders(t *testing.T) {
	h, _, b, req := setup()
	req.Body = base64.StdEncoding.EncodeToString([]byte(req.Body))
	req.IsBase64Encoded = true
	req.Headers = map[string]string{"x-gitlab-token": "test-secret", "x-gitlab-event": "Job Hook"}
	checkStatus(t, h, req, 200)
	if len(b.inputs) != 1 {
		t.Fatal("base64 request did not start a worker")
	}
}

func TestInvalidTokensCannotStartBuild(t *testing.T) {
	for _, token := range []string{"wrong", "", "한글"} {
		t.Run(token, func(t *testing.T) {
			h, _, b, req := setup()
			req.Headers["X-Gitlab-Token"] = token
			checkStatus(t, h, req, 401)
			if len(b.inputs) != 0 {
				t.Fatal("unauthenticated request started build")
			}
		})
	}
}

func TestDisabledAndNonPostNeverCallAWS(t *testing.T) {
	h, s, b, req := setup()
	h.enabled = false
	checkStatus(t, h, req, 503)
	req.RequestContext.HTTP.Method = "GET"
	checkStatus(t, h, req, 405)
	if s.calls != 0 || len(b.inputs) != 0 {
		t.Fatal("disabled/GET request called AWS")
	}
}

func TestOtherProjectAndStatusesAreIgnored(t *testing.T) {
	for _, replacement := range []struct{ old, new string }{
		{`1444183`, `2`}, {`"build"`, `"pipeline"`},
		{`"pending"`, `"running"`},
		{`"pending"`, `"created"`},
		{`"pending"`, `"success"`}, {`"pending"`, `"failed"`},
		{`"pending"`, `"canceled"`}, {`"pending"`, `"manual"`},
	} {
		t.Run(replacement.new, func(t *testing.T) {
			h, _, b, req := setup()
			req.Body = strings.Replace(req.Body, replacement.old, replacement.new, 1)
			checkStatus(t, h, req, 200)
			if len(b.inputs) != 0 {
				t.Fatal("unrelated event started build")
			}
		})
	}
}

func TestPushHookIsIgnored(t *testing.T) {
	h, _, b, req := setup()
	req.Headers["X-Gitlab-Event"] = "Push Hook"
	checkStatus(t, h, req, 200)
	if len(b.inputs) != 0 {
		t.Fatal("Push Hook started build")
	}
}

func TestMalformedBody(t *testing.T) {
	for _, body := range []string{"{", "[]", "null", "", `{} {}`} {
		t.Run(body, func(t *testing.T) {
			h, _, b, req := setup()
			req.Body = body
			checkStatus(t, h, req, 400)
			if len(b.inputs) != 0 {
				t.Fatal("malformed body started build")
			}
		})
	}
	h, _, _, req := setup()
	req.IsBase64Encoded, req.Body = true, "%%%"
	checkStatus(t, h, req, 400)
}

func TestInvalidJobID(t *testing.T) {
	for _, id := range []string{"null", "true", "0", "-1", `"123"`, "1.5", "1e3", "18446744073709551616"} {
		t.Run(id, func(t *testing.T) {
			h, _, b, req := setup()
			req.Body = strings.Replace(req.Body, `"build_id":123`, `"build_id":`+id, 1)
			checkStatus(t, h, req, 400)
			if len(b.inputs) != 0 {
				t.Fatal("invalid job ID started build")
			}
		})
	}
}

func TestAWSFailureIsNotAcknowledged(t *testing.T) {
	h, _, b, req := setup()
	b.err = errors.New("AWS unavailable")
	checkStatus(t, h, req, 503)
}

func TestSecretFailure(t *testing.T) {
	h, s, b, req := setup()
	s.err = errors.New("missing secret")
	checkStatus(t, h, req, 503)
	s.err, s.value = nil, nil
	checkStatus(t, h, req, 503)
	s.value = aws.String("")
	checkStatus(t, h, req, 401)
	if len(b.inputs) != 0 {
		t.Fatal("secret lookup failure started build")
	}
}

func TestOversizedBody(t *testing.T) {
	h, _, b, req := setup()
	req.Body = strings.Repeat("x", 131073)
	checkStatus(t, h, req, 413)
	if len(b.inputs) != 0 {
		t.Fatal("oversized body started build")
	}
}

func TestRequestCancellationReachesAWS(t *testing.T) {
	h, _, b, req := setup()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	got, err := h.Handle(ctx, req)
	if err != nil || got.StatusCode != 503 || len(b.inputs) != 0 {
		t.Fatal("canceled request was not stopped")
	}
}

func TestCreatedThenPendingDoesNotPrematurelyClaimJob(t *testing.T) {
	h, _, b, req := setup()
	pending := req.Body
	req.Body = strings.ReplaceAll(req.Body, "pending", "created")
	checkStatus(t, h, req, 200)
	if len(b.inputs) != 0 {
		t.Fatal("created started a worker")
	}
	req.Body = pending
	checkStatus(t, h, req, 200)
	if len(b.inputs) != 1 {
		t.Fatal("pending was suppressed")
	}
}

func TestConcurrentDuplicateDeliveriesStartOneWorker(t *testing.T) {
	h, _, b, req := setup()
	var wg sync.WaitGroup
	for i := 0; i < 40; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			response, err := h.Handle(context.Background(), req)
			if err != nil || (response.StatusCode != 200 && response.StatusCode != 503) {
				t.Errorf("unexpected response: %v %v", response, err)
			}
		}()
	}
	wg.Wait()
	if len(b.inputs) != 1 {
		t.Fatalf("started %d workers", len(b.inputs))
	}
}

func TestKnownRejectionAllowsRetryWithSameToken(t *testing.T) {
	h, _, b, req := setup()
	b.err = &smithy.GenericAPIError{Code: "AccountLimitExceededException", Message: "limit reached"}
	checkStatus(t, h, req, 503)
	b.err = nil
	checkStatus(t, h, req, 200)
	checkStatus(t, h, req, 200)
	if len(b.inputs) != 2 || !reflect.DeepEqual(b.inputs[0], b.inputs[1]) {
		t.Fatal("rejected request cannot be retried safely")
	}
}

func TestUncertainStartNeverStartsAgain(t *testing.T) {
	h, _, b, req := setup()
	b.err = context.DeadlineExceeded
	checkStatus(t, h, req, 503)
	b.err = nil
	checkStatus(t, h, req, 503)
	if len(b.inputs) != 1 {
		t.Fatal("uncertain result started a duplicate")
	}
}

func TestRecordFailureNeverStartsAgain(t *testing.T) {
	h, _, b, req := setup()
	h.jobs.(*memoryJobs).completeErr = errors.New("store unavailable")
	checkStatus(t, h, req, 503)
	checkStatus(t, h, req, 503)
	if len(b.inputs) != 1 {
		t.Fatal("record failure started a duplicate")
	}
}
