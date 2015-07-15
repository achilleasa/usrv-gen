# {{ .SrvName }}

{{ .SrvDescription }}

# Dependencies

To use this package you need the following dependencies:
```
go get golang.org/x/net/context
go get "code.google.com/p/go-uuid/uuid"
{{ if eq .UseEtcd true }}go get github.com/coreos/go-etcd/...
go get github.com/ugorji/go/codec{{end}}
go get -u github.com/golang/protobuf/{proto,protoc-gen-go}
go get github.com/achilleasa/{service-adapters,usrv}
```

# Getting started


# Messages

This service uses protocol buffers. The service request and response messages are defined in the `messages.proto` file.
Whenever you make a change to the .proto file you need to regenerate the go message bindings. To do this run:
`go generate` inside your service folder.

# The client

# Testing
