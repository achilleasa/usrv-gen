# usrv-gen

A microservice generator for the [usrv](https://github.com/achilleasa/usrv) framework.

This tool provides an easy way to bootstrap new usrv services for your application. Features:
- AMQP as the transport layer.
- Protocol buffers for message exchange.
- Support for incoming request throttling (max concurrent connections) and execution deadlines.
- Support for request tracing via the [usrv-tracer](https://github.com/achilleasa/usrv-tracer) package with redis as the storage backend.
- Generation of both the server and the client (real and mock for running integration tests).
- Dynamic service configuration via etcd.

# Getting started

Please note that this package is still work in progress.

The following example will generate service `go-usrv-example` under the `github.com/foo` folder inside the current
go workspace (`GOPATH` needs to be present in your env vars or the generator will fail with an error). The service will
listen for incoming requests on a queue named `com.foo.example`. It will throttle incoming requests to 1000 concurrent
(no execution time limit) and log request/response trace entries to redis with a 1 day ttl.

```
go run main.go \
   --srv-path="github.com/foo/go-usrv-example" \
   --srv-descr="A description for the service" \
   --srv-endpoint="com.foo.example" \
   --throttle-enabled --throttle-max-concurrent=1000 --throttle-max-exec-time=0 \
   --tracer-enabled --tracer-queue-size=1000 --tracer-entry-ttl=86400 \
   --init-git-repo \
   --etcd-enabled

Creating new usrv service at ~/go/src/github.com/foo/go-usrv-example
✓  Processing: templates/.gitignore.tpl -> .gitignore
✓  Processing: templates/README.md.tpl -> README.md
✓  Processing: templates/client.go.tpl -> client.go
✓  Processing: templates/main/main.go.tpl -> main/main.go
✓  Processing: templates/messages.proto.tpl -> messages.proto
✓  Processing: templates/server.go.tpl -> server.go
✓  Processing: templates/service_impl.go.tpl -> service_impl.go
✓  Creating initial protobuf bindings
✓  Init empty git repo

Notes:
- The service protobuf messages are defined in ~/go/src/github.com/foo/go-usrv-example/messages.proto.
  After making any changes to the .proto file run 'go generate' to rebuild the go bindings.
- Add your service implementation inside ~/go/src/github.com/foo/go-usrv-example/service_impl.go.
- The service is set up to use etcd for automatic configuration.
  See ~/go/src/github.com/foo/go-usrv-example/README.md for more details.
- An empty git repo has been created for you.
```

# Service implementation details

Add your service implementation details to the `service_impl.go` file. The same file also defines a bootstrap init
function that you can hook to perform one-time initialization of your service, setup connections or create
clients for the services you need e.t.c

# Building and running your service

To build your server executable switch to the main folder inside the generated service and type:
`go build`

To run the service just run the compiled executable. The service expects an etcd server to be available at
`http://127.0.0.1:4001`. To use a different etcd host (e.g running inside a docker container) you just need
to define the `ETCD_HOSTS` env var with a comma-delimited list of etcd hosts to try prior to running the server.

To exit a running server send it a `SIGINT` or press `ctrl+c` if running in interactive mode.

# The request and response messages

The generator defines a `Request` and `Response` protobuf message for the service. The protobuf messages are defined
in the `messages.proto` file. If you make any changes to the `messages.proto` file you need to rebuild the go bindings via
running `go generate` inside the service folder.

# License

usrv-gen is distributed under the [MIT license](https://github.com/achilleasa/usrv-genr/blob/master/LICENSE).
