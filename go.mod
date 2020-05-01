module github.com/owncloud/ocis-migration

go 1.13

require (
	github.com/UnnoTed/fileb0x v1.1.4
	github.com/cs3org/go-cs3apis v0.0.0-20200408065125-6e23f3ecec0a
	github.com/cs3org/reva v0.1.0
	github.com/micro/cli/v2 v2.1.1
	github.com/micro/go-micro v1.18.0
	github.com/micro/go-micro/v2 v2.0.0
	github.com/owncloud/ocis-accounts v0.1.0
	github.com/owncloud/ocis-pkg/v2 v2.0.1
	github.com/restic/calens v0.2.0
	github.com/spf13/viper v1.6.1
	google.golang.org/grpc v1.28.1
)

replace google.golang.org/grpc => google.golang.org/grpc v1.26.0
