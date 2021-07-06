// +build integration
// +build smoketest

package stdout

import (
	"os"
	"os/exec"
	"regexp"
	"strings"
	"testing"

	"github.com/calyptia/fluent-bit-ci/integration/tests"
	"github.com/stretchr/testify/suite"
)

type Suite struct {
	tests.BaseTestSuite
}

func TestSuite(t *testing.T) {
	s := &Suite{BaseTestSuite: tests.BaseTestSuite{Name: "stdout"}}
	suite.Run(t, s)
}

func (s *Suite) TestDummyInputToStdoutOutput() {
	assert := s.BaseTestSuite.Assert()

	fluentbitbin, present := os.LookupEnv("FLUENT_BIT_BIN")
	if present == false {
		fluentbitbin = "fluent-bit"
	}

	cmd := exec.Command(fluentbitbin,
		"-q",
		"-f", "1",
		"-i", "dummy",
		"-o", "stdout",
		"-p", "match=*",
		"-o", "exit",
		"-p", "match=*")

	out, err := cmd.Output()
	s.Nil(err)

	lines := strings.Split(string(out), "\n")
	r := "^\\[\\d+\\] dummy\\.0: \\[\\d+\\.\\d+, \\{\\\"message\\\"\\=\\>\\\"dummy\\\"\\}\\]$"
	rx := regexp.MustCompile(r)

	for _, line := range lines {
		if line == "" {
			continue
		}
		assert.Regexp(rx, line)
	}
}
