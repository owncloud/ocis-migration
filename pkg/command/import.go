package command

import (
	"context"
	"encoding/json"
	"github.com/cs3org/go-cs3apis/cs3/gateway/v1beta1"
	revauser "github.com/cs3org/go-cs3apis/cs3/identity/user/v1beta1"
	"github.com/cs3org/reva/pkg/token"
	"github.com/cs3org/reva/pkg/token/manager/jwt"
	"github.com/micro/cli/v2"
	"github.com/micro/go-micro/registry"
	"github.com/micro/go-micro/v2/client/grpc"
	accounts "github.com/owncloud/ocis-accounts/pkg/proto/v0"
	"github.com/owncloud/ocis-migration/pkg/config"
	"github.com/owncloud/ocis-migration/pkg/flagset"
	"github.com/owncloud/ocis-migration/pkg/migrate"
	googlegrpc "google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
	"io/ioutil"
	"os"
	"path"
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
		Flags: flagset.ImportWithConfig(cfg),
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
			conn, err := googlegrpc.Dial(addr, googlegrpc.WithInsecure())
			if err != nil {
				logger.Fatal().Err(err).Msgf("Reva not reachable")
			}

			gatewayClient := gatewayv1beta1.NewGatewayAPIClient(conn)

			tokenManager, err := jwt.New(map[string]interface{}{
				"secret":  c.String("jwt-secret"),
				"expires": int64(99999999999),
			})

			if err != nil {
				logger.Fatal().Err(err).Msgf("Could not load token-manager")
			}

			t, err := tokenManager.MintToken(c.Context, &revauser.User{
				Id: &revauser.UserId{
					OpaqueId: u.User.UserID,
				},
				Username: u.User.UserID,
			})

			if err != nil {
				logger.Fatal().Err(err).Msgf("Error minting token")
			}

			ctx := token.ContextSetToken(context.Background(), t)
			ctx = metadata.AppendToOutgoingContext(ctx, token.TokenHeader, t)

			if err := migrate.ImportMetadata(ctx, gatewayClient, importPath, "/home"); err != nil {
				logger.Fatal().Err(err).Msg("Importing metadata failed")
			}

			if err := migrate.ImportShares(ctx, gatewayClient, importPath, "/home"); err != nil {
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
