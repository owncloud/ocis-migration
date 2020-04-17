package command

import (
	"context"
	"encoding/json"
	"github.com/owncloud/ocis-migration/pkg/migrate"
	"io/ioutil"
	"os"
	"path"

	"github.com/cs3org/go-cs3apis/cs3/gateway/v1beta1"
	"github.com/cs3org/reva/pkg/token"
	"github.com/micro/cli/v2"
	"github.com/micro/go-micro/registry"
	"github.com/micro/go-micro/v2/client/grpc"
	accounts "github.com/owncloud/ocis-accounts/pkg/proto/v0"
	"github.com/owncloud/ocis-migration/pkg/config"
	grpc2 "google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
)

type user struct {
	UserID      string `json:"userId"`
	Email       string `json:"email"`
	DisplayName string `json:"displayName"`
}

type exportData struct {
	Date         string `json:"date"`
	OriginServer string `json:"originServer"`
	User         user   `json:"user"`
}

// Import is the entrypoint for the import command.
func Import(cfg *config.Config) *cli.Command {
	return &cli.Command{
		Name:  "import",
		Usage: "Import a user",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "import-path",
				Usage:   "Path to exported user-directory",
				Value:   "",
				EnvVars: []string{"MIGRATION_IMPORT_PATH"},
			},
		},
		Action: func(c *cli.Context) error {
			logger := NewLogger(cfg)

			importPath := c.String("import-path")
			if importPath == "" {
				logger.Fatal().Msg("No import-path specified")
			}

			info, err := os.Stat(importPath)
			if err != nil {
				logger.Fatal().Err(err).Msg("Could not open export")
			}

			if !info.IsDir() {
				logger.Fatal().Msg("Import path must be a directory")
			}

			userMetaDataPath := path.Join(importPath, "user.json")
			data, err := ioutil.ReadFile(userMetaDataPath)

			if err != nil {
				logger.Fatal().Err(err).Msgf("Could not read file")
			}

			u := &exportData{}
			if err := json.Unmarshal(data, u); err != nil {
				logger.Fatal().Err(err).Msgf("Could not decode json")
			}

			svc, err := registry.GetService("com.owncloud.reva")
			if err != nil {
				logger.Fatal().Err(err).Msgf("Service not found")
			}

			addr := svc[0].Nodes[0].Address
			conn, err := grpc2.Dial(addr, grpc2.WithInsecure())
			if err != nil {
				logger.Fatal().Err(err).Msgf("Service not reachable")
			}

			gwClient := gatewayv1beta1.NewGatewayAPIClient(conn)

			//TODO: MintToken from authbasic secret
			resp, err := gwClient.Authenticate(c.Context, &gatewayv1beta1.AuthenticateRequest{
				Type:         "basic",
				ClientId:     "einstein",
				ClientSecret: "relativity",
			})

			if err != nil {
				logger.Fatal().Err(err).Msgf("Could not authenticate")
			}

			t := resp.GetToken()

			ctx := token.ContextSetToken(context.Background(), t)
			ctx = metadata.AppendToOutgoingContext(ctx, token.TokenHeader, t)

			err = migrate.ImportMetadata(ctx, gwClient, importPath, "/home")
			if err != nil {
				logger.Fatal().Err(err).Msg("Importing metadata failed")
			}

			err = migrate.ImportShares(ctx, gwClient, importPath, "/home")
			if err != nil {
				logger.Fatal().Err(err).Msg("Importing shares failed")
			}

			ss := accounts.NewSettingsService("com.owncloud.accounts", grpc.NewClient())
			_, err = ss.Set(c.Context, &accounts.Record{
				Key: u.User.UserID,
				Payload: &accounts.Payload{
					Account: &accounts.Account{
						StandardClaims: nil,
					},
				},
			})

			if err != nil {
				logger.Fatal().Err(err).Msgf("Could not create entry in ocis-accounts")
			}

			return nil
		}}
}
