module github.com/owncloud/ocis-migration

go 1.13

require (
	github.com/UnnoTed/fileb0x v1.1.4
	github.com/cs3org/go-cs3apis v0.0.0-20200408065125-6e23f3ecec0a
	github.com/cs3org/reva v0.1.0
	github.com/micro/cli/v2 v2.1.2
	github.com/micro/go-micro v1.18.0
	github.com/micro/go-micro/v2 v2.0.1-0.20200212105717-d76baf59de2e
	github.com/owncloud/ocis-accounts v0.1.0
	github.com/owncloud/ocis-pkg/v2 v2.2.1
	github.com/restic/calens v0.2.0
	github.com/spf13/viper v1.6.3
	google.golang.org/grpc v1.28.1
)

replace github.com/owncloud/ocis-accounts => ../ocis-accounts

replace github.com/owncloud/ocis-settings => ../ocis-settings
