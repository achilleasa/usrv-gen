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
go workspace (`GOPATH` needs to be present in your env vars or the generator will fail with an error). The generated
service will:
- use etcd for configuration and amqp as the transport layer
- expose an endpoint called `Foo` with the fully qualified name `com.foo.example.Foo`
- expose an endpoint called `Bar` with the fully qualified name `com.foo.example.Bar`
- generate protocol buffer stubs for request/response messages to the above endpoints and execute proto-c
- throttle incoming requests (1000 concurrent, no exec limit)
- log request/response traces to redis (also configured via etcd) with a 1-day TTL.

```
go run usrv-gen.go \
   --srv-path="github.com/foo/go-usrv-example" \
   --srv-descr="A description for the service" \
   --srv-base="com.foo.example" \
   --srv-endpoint="Foo" \
   --srv-endpoint="Bar" \
   --throttle-enabled --throttle-max-concurrent=1000 --throttle-max-exec-time=0 \
   --tracer-enabled --tracer-queue-size=1000 --tracer-entry-ttl=86400 \
   --init-git-repo \
   --etcd-enabled

Creating new usrv service at ~/go/src/github.com/foo/go-usrv-example
✓  Processing: templates/.gitignore_tpl -> .gitignore
✓  Processing: templates/README.md_tpl -> README.md
✓  Processing: templates/client.go_tpl -> client.go
✓  Processing: templates/endpoints.go_tpl -> endpoints.go
✓  Processing: templates/launch/launch.go_tpl -> launch/launch.go
✓  Processing: templates/messages.proto_tpl -> messages.proto
✓  Processing: templates/server.go_tpl -> server.go
✓  Processing: templates/service.go_tpl -> service.go
✓  Running go fmt
✓  Creating initial protobuf bindings
✓  Init empty git repo

Notes:
- The service protobuf messages are defined in ~/go/src/github.com/foo/go-usrv-example/messages.proto.
  After making any changes to the .proto file run 'go generate' to rebuild the go bindings.
- Add your service implementation inside ~/go/src/github.com/foo/go-usrv-example/service.go.
- The service is set up to use etcd for automatic configuration.
  See ~/go/src/github.com/foo/go-usrv-example/README.md for more details.
- An empty git repo has been created for you.
```

# Service implementation details

Add your service implementation details to the `service.go` file inside each generated `Handler` method.

The same file also defines the `InitService` function which will be invoked before the server starts.
You can use this hook  to perform one-time initialization of your service, setup connections or create
clients for the external services you need.

# Building and running your service

To build your server executable switch to the `launch` folder inside the generated service and type:
`go build`

To run the service just run the compiled executable. The service expects an etcd server to be available at
`http://127.0.0.1:4001`. To use a different etcd host (e.g running inside a docker container) or a list
 of multiple comma-delimited hosts you can either:
- specify the `--etcd-hosts` command line argument
- define the `ETCD_HOSTS` env var

To exit a running server send it a `SIGINT` or press `ctrl+c` if running in interactive mode.

# The request and response messages

## Using protobuf (default)
The generator defines a `Request` and `Response` protobuf message for the each exposed service endpoint. The protobuf
messages are defined in the `messages.proto` file. If you make any changes to the `messages.proto` file you need to
rebuild the go bindings via running `go generate` inside the service folder.

## Using json

If you want to use json instead of protocol buffers for your service pass the
`srv-message-type=json` command-line option to the generator. In this case, the `Request` and
`Response` objects will be defined inside the generated `messages.go` file.

# License

usrv-gen is distributed under the [MIT license](https://github.com/achilleasa/usrv-genr/blob/master/LICENSE).
