package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"
)

// The set of accepted flags
var (
	srvPath               = flag.String("srv-path", "", "Service path (e.g github.com/foo/foo-srv)")
	endpoint              = flag.String("srv-endpoint", "", "Service endpoint. If omitted the service name will be used")
	description           = flag.String("srv-descr", "", "Service description")
	initGitRepo           = flag.Bool("init-git-repo", true, "Initialize a git repo at the output folder")
	overwrite             = flag.Bool("overwrite-files", false, "Overwrite files in output folder if the folder already exists")
	useEtcd               = flag.Bool("etcd-enabled", true, "Use etcd for service discovery")
	useThrottle           = flag.Bool("throttle-enabled", false, "Use request throttle middleware")
	throttleMaxConcurrent = flag.Int("throttle-max-concurrent", 1000, "Max concurrent service requests")
	throttleMaxExecTime   = flag.Int("throttle-max-exec-time", 0, "Max execution time for a request in ms. No limit if set to 0")
	useTracer             = flag.Bool("tracer-enabled", true, "Use request tracing middleware")
	tracerQueueSize       = flag.Int("tracer-queue-size", 1000, "Max concurrent trace messages in queue")
	tracerTTL             = flag.Int("tracer-entry-ttl", 24*3600, "Trace entry TTL in seconds. TTL will be disabled if set to 0")

	pkgFolder = ""
	srvName   = ""
)

// Get the list of templates (*.tpl) under path. The method will scan the path recursively.
func getTemplates(path string) []string {
	list := make([]string, 0)
	filepath.Walk(path, func(path string, info os.FileInfo, err error) error {
		// Recurse into dirs
		if info.IsDir() {
			return nil
		}

		if strings.HasSuffix(info.Name(), ".tpl") {
			list = append(list, path)
		}

		return nil
	})

	return list
}

func parseArgs() error {
	flag.Parse()

	gopath := os.Getenv("GOPATH")
	if gopath == "" {
		return fmt.Errorf("GOPATH env var not defined")
	}

	// Trim trailing slash if present
	*srvPath = strings.TrimRight(*srvPath, "/")

	if *srvPath == "" {
		return fmt.Errorf("Please specify the service path with the --srv-path option")
	}

	srvName = (*srvPath)[strings.LastIndex(*srvPath, "/")+1:]

	pkgFolder = fmt.Sprintf("%s/src/%s", gopath, *srvPath)
	info, err := os.Stat(pkgFolder)
	if err == nil {
		if !info.IsDir() {
			return fmt.Errorf("Specified package folder %s is actually a file", pkgFolder)
		}
		if !*overwrite {
			return fmt.Errorf("Specified package folder %s already exists. Use the --overwrite-files flag to proceed", pkgFolder)
		}
	}

	if *endpoint == "" {
		*endpoint = srvName
	}
	return nil
}

func initGit() error {
	fmt.Printf("\r\u274C  Initing empty git repo")
	err := exec.Command("git", "init", pkgFolder).Run()
	if err != nil {
		fmt.Printf("\r\u274C  Initing empty git repo\n")
		return fmt.Errorf("Error initializing git repo: %s", err.Error())
	}
	fmt.Printf("\r\u2713  Initing empty git repo\n")

	return nil
}

func initBindings() error {
	fmt.Printf("\r\u274C  Creating initial protobuf bindings")
	err := exec.Command(
		"protoc",
		fmt.Sprintf("--%s=%s", "go_out", pkgFolder),
		fmt.Sprintf("--proto_path=%s", pkgFolder),
		fmt.Sprintf("%s/messages.proto", pkgFolder),
	).Run()
	if err != nil {
		fmt.Printf("\r\u274C  Creating initial protobuf bindings\n")
		return fmt.Errorf("Error running protoc: %s", err.Error())
	}
	fmt.Printf("\r\u2713  Creating initial protobuf bindings\n")

	return nil
}

func genService() error {

	var err error

	fmt.Printf("Creating new usrv service at %s\n", pkgFolder)
	err = os.MkdirAll(pkgFolder, os.ModeDir|os.ModePerm)
	if err != nil {
		return fmt.Errorf("Error creating folder %s: %s", pkgFolder, err.Error())
	}

	// Build context
	context := map[string]interface{}{
		"PkgName":               "srv",
		"SrvPath":               *srvPath,
		"SrvName":               srvName,
		"SrvDescription":        *description,
		"SrvEndpoint":           *endpoint,
		"UseEtcd":               *useEtcd,
		"UseThrottle":           *useThrottle,
		"ThrottleMaxConcurrent": *throttleMaxConcurrent,
		"ThrottleMaxExecTime":   *throttleMaxExecTime,
		"UseTracer":             *useTracer,
		"TracerQueueSize":       *tracerQueueSize,
		"TracerTTL":             *tracerTTL,
	}

	// Execute templates
	for _, tplFile := range getTemplates("templates") {
		// Strip the .tpl extension and the templates/ prefix
		dstFilename := strings.Replace(
			strings.Replace(tplFile, ".tpl", "", 1),
			"templates/",
			"",
			1,
		)

		// Template contains a folder?
		if strings.Index(dstFilename, "/") != -1 {
			dstFolder := fmt.Sprintf(
				"%s/%s",
				pkgFolder,
				dstFilename[0:strings.LastIndex(dstFilename, "/")],
			)
			err = os.MkdirAll(dstFolder, os.ModeDir|os.ModePerm)
			if err != nil {
				return fmt.Errorf("Error creating folder %s: %s", dstFolder, err.Error())
			}
		}

		// Read template
		tplData, err := ioutil.ReadFile(tplFile)
		if err != nil {
			return fmt.Errorf("Error reading template %s: %s", tplFile, err.Error())
		}

		tpl, err := template.New(dstFilename).Parse(string(tplData))
		if err != nil {
			return fmt.Errorf("Error parsing template %s: %s", tplFile, err.Error())
		}

		dstPath := fmt.Sprintf("%s/%s", pkgFolder, dstFilename)
		outFile, err := os.Create(dstPath)
		if err != nil {
			return fmt.Errorf("Error opening %s for writing: %s", dstPath, err.Error())
		}
		fmt.Printf("\r\u231B  Processing: %s -> %s", tplFile, dstFilename)
		defer outFile.Close()

		err = tpl.Execute(outFile, context)
		if err != nil {
			fmt.Printf("\r\u274C  Processing: %s -> %s\n", tplFile, dstFilename)
			return fmt.Errorf("Error executing template %s: %s", tplFile, err.Error())
		}
		fmt.Printf("\r\u2713  Processing: %s -> %s\n", tplFile, dstFilename)
	}

	fmt.Printf("\u2713  Service created successfully")

	// Create initial bindings
	err = initBindings()
	if err != nil {
		return err
	}

	// Init git repo
	if *initGitRepo {
		err = initGit()
		if err != nil {
			return err
		}
	}

	fmt.Println("\nNotes:")
	fmt.Printf("- The service protobuf messages are defined in %s/messages.proto.\n  After making any changes to the .proto file run 'go generate' to rebuild the go bindings.\n", pkgFolder)
	fmt.Printf("- Add your service implementation inside %s/service_impl.go.\n", pkgFolder)
	if *useEtcd {
		fmt.Printf("- The service is set up to use etcd for automatic configuration.\n  See %s/README.md for more details.\n", pkgFolder)
	}
	if *initGitRepo {
		fmt.Printf("- An empty git repo has been created for you.\n")
	}
	fmt.Printf("\n\n")
	return nil
}

func main() {
	// Preflight checks
	_, err := exec.LookPath("protoc-gen-go")
	if err != nil {
		fmt.Fprintf(os.Stderr, "\u274C  protoc-gen-go not be located in your current $PATH\n   Try running: go get -u github.com/golang/protobuf/{proto,protoc-gen-go}\n")
		os.Exit(1)
	}

	// Parse args
	err = parseArgs()
	if err != nil {
		fmt.Fprintf(os.Stderr, "\u274C  %s\n\n", err.Error())
		flag.Usage()
		os.Exit(1)
	}

	// Create service
	err = genService()
	if err != nil {
		fmt.Printf("\u274C  %s\n", err.Error())
		os.Exit(1)
	}
}
