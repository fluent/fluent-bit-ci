// +build integration

package bigquery

import (
	bq "cloud.google.com/go/bigquery"
	"context"
	"fmt"
	"github.com/calyptia/fluent-bit-ci/integration/tests"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"google.golang.org/api/iterator"
	"os"
	"time"
)

type Suite struct {
	tests
}

func queryBasic(projectID string, tableID string) ([]bq.value, error) {
	ctx := context.Background()
	client, err := bq.NewClient(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("bigquery.NewClient: %v", err)
	}
	defer client.Close()

	q := client.Query(fmt.Sprintf("SELECT count(*) FROM `%s.testing_dataset.%s`", projectID, tableID))
	q.Location = "US"
	job, err := q.Run(ctx)
	if err != nil {
		return nil, err
	}
	status, err := job.Wait(ctx)
	if err != nil {
		return nil, err
	}
	if err := status.Err(); err != nil {
		return nil, err
	}
	it, err := job.Read(ctx)
	for {
		var row []bq.Value
		err := it.Next(&row)
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, err
		}

		return row, nil
	}

	return nil, fmt.Errorf("no results found")
}

func GetEnv(key string, defaultVal string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultVal
}

const DefaultMaxRetries = 5
const DefaultRetryTimeout = 1 * time.Minute

func (suite *Suite) TestDummyInputBigQueryOutput() {

	cfg, _ := suite.RenderCfgFromTpl("dummy_input_bigquery_output", "", nil)
	opts, _ := suite.GetTerraformOpts(cfg)

	defer terraform.Destroy(suite.T(), opts)
	terraform.InitAndApply(suite.T(), opts)

	retry.DoWithRetry(suite.T(), "Check if bigquery table has entries", tests.DefaultMaxRetries, tests.DefaultRetryTimeout, func() (string, error) {
		var results []bq.result
		var err error
		if results, err = queryBasic(GetEnv("GCP_PROJECT_ID", ""), GetEnv("GCP_BQ_TABLE_ID", "")); err != nil {
			return "", err
		}
		if len(results) <= 0 {
			return "", fmt.Errorf("no found results")
		}

		return "", nil
	})
}