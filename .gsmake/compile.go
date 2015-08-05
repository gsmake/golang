package tasks

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/gsdocker/gserrors"
	"github.com/gsdocker/gsos/fs"
	"github.com/gsmake/gsmake"
	"github.com/gsmake/gsmake/property"
)

// TaskResource compile golang resources
func TaskResource(runner *gsmake.Runner, args ...string) error {
	return nil
}

// TaskCompile compile golang resources
func TaskCompile(runner *gsmake.Runner, args ...string) error {

	// get compile binary path
	var binaries map[string]string

	err := runner.Property("golang", runner.Name(), "gsmake.golang.binary", &binaries)

	if err != nil {

		if property.NotFound(err) {
			return nil
		}

		return err
	}

	if len(binaries) == 0 {
		return nil
	}

	gopath := runner.RootFS().DomainDir("golang")

	if err := os.Setenv("GOPATH", gopath); err != nil {
		return gserrors.Newf(err, "set GOPATH error :%s", gopath)
	}

	runner.D("set GOPATH :%s", gopath)

	packagepath, err := runner.Path("golang", runner.Name())

	if err != nil {
		return err
	}

	for name, binary := range binaries {

		path := filepath.Join(packagepath, binary)

		targetpath := filepath.Join("bin", name+fs.ExeSuffix)

		runner.I("compile binary : %s", targetpath)

		cmd := exec.Command("go", "build", "-o", filepath.Join(packagepath, targetpath))

		cmd.Dir = path

		var buff bytes.Buffer

		cmd.Stderr = &buff

		err := cmd.Run()

		if err != nil {
			return gserrors.Newf(err, buff.String())
		}
	}

	return nil
}
