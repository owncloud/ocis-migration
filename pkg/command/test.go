package command

import (
	"github.com/micro/cli/v2"
	"github.com/micro/go-micro/v2"
	accounts "github.com/owncloud/ocis-accounts/pkg/proto/v0"
	"github.com/owncloud/ocis-migration/pkg/config"
	"os"
)

// Import is the entrypoint for the import command.
func Test(cfg *config.Config) *cli.Command {
	return &cli.Command{
		Name:  "test",
		Usage: "wefwefwe",
		Action: func(c *cli.Context) error {
			logger := NewLogger(cfg)

			service := micro.NewService(
				micro.Name("com.owncloud.migration.client"), //name the client service
			)
			// Initialise service
			service.Init()

			logger.Debug().Msg("Creating entry in com.owncloud.accounts")
			svcList, err := service.Options().Registry.ListServices()
			//svcList, err := reg2.ListServices()
			if err != nil {
				logger.Fatal().Err(err).Msgf("Could not list services: %v", err)
			}

			for _, svc := range svcList {
				logger.Info().Msgf("Service: %v", svc.Name)
				for _, node := range svc.Nodes {
					logger.Info().Msgf("Node: %v", node.Address)
				}
			}

			env := os.Getenv("MICRO_REGISTRY")
			_ = env

			logger.Info().Msgf("Service List: %#v", svcList)
			ss := accounts.NewSettingsService("com.owncloud.accounts", service.Client())
			_, err = ss.Set(c.Context, &accounts.Record{
				Key: "einstein",
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
