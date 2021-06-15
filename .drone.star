def main(ctx):
    before = [
        testing(ctx),
    ]

    stages = [
        docker(ctx, "amd64"),
        docker(ctx, "arm64"),
        docker(ctx, "arm"),
        binary(ctx, "linux"),
        binary(ctx, "darwin"),
        binary(ctx, "windows"),
    ]

    after = [
        manifest(ctx),
        changelog(ctx),
        readme(ctx),
        website(ctx),
    ]

    return before + stages + after

def testing(ctx):
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "testing",
        "platform": {
            "os": "linux",
            "arch": "amd64",
        },
        "steps": [
            {
                "name": "generate",
                "image": "webhippie/golang:1.13",
                "pull": "always",
                "commands": [
                    "make generate",
                ],
                "volumes": [
                    {
                        "name": "gopath",
                        "path": "/srv/app",
                    },
                ],
            },
            {
                "name": "vet",
                "image": "webhippie/golang:1.13",
                "pull": "always",
                "commands": [
                    "make vet",
                ],
                "volumes": [
                    {
                        "name": "gopath",
                        "path": "/srv/app",
                    },
                ],
            },
            {
                "name": "staticcheck",
                "image": "webhippie/golang:1.13",
                "pull": "always",
                "commands": [
                    "make staticcheck",
                ],
                "volumes": [
                    {
                        "name": "gopath",
                        "path": "/srv/app",
                    },
                ],
            },
            {
                "name": "lint",
                "image": "webhippie/golang:1.13",
                "pull": "always",
                "commands": [
                    "make lint",
                ],
                "volumes": [
                    {
                        "name": "gopath",
                        "path": "/srv/app",
                    },
                ],
            },
            {
                "name": "build",
                "image": "webhippie/golang:1.13",
                "pull": "always",
                "commands": [
                    "make build",
                ],
                "volumes": [
                    {
                        "name": "gopath",
                        "path": "/srv/app",
                    },
                ],
            },
            {
                "name": "test",
                "image": "webhippie/golang:1.13",
                "pull": "always",
                "commands": [
                    "make test",
                ],
                "volumes": [
                    {
                        "name": "gopath",
                        "path": "/srv/app",
                    },
                ],
            },
            {
                "name": "codacy",
                "image": "plugins/codacy:1",
                "pull": "always",
                "settings": {
                    "token": {
                        "from_secret": "codacy_token",
                    },
                },
            },
        ],
        "volumes": [
            {
                "name": "gopath",
                "temp": {},
            },
        ],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/tags/**",
                "refs/pull/**",
            ],
        },
    }

def docker(ctx, arch):
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "docker-%s" % (arch),
        "platform": {
            "os": "linux",
            "arch": arch,
        },
        "steps": [
            {
                "name": "generate",
                "image": "webhippie/golang:1.13",
                "pull": "always",
                "commands": [
                    "make generate",
                ],
                "volumes": [
                    {
                        "name": "gopath",
                        "path": "/srv/app",
                    },
                ],
            },
            {
                "name": "build",
                "image": "webhippie/golang:1.13",
                "pull": "always",
                "commands": [
                    "make build",
                ],
                "volumes": [
                    {
                        "name": "gopath",
                        "path": "/srv/app",
                    },
                ],
            },
            {
                "name": "dryrun",
                "image": "plugins/docker:latest",
                "pull": "always",
                "settings": {
                    "dry_run": True,
                    "tags": "linux-%s" % (arch),
                    "dockerfile": "docker/Dockerfile.linux.%s" % (arch),
                    "repo": ctx.repo.slug,
                },
                "when": {
                    "ref": {
                        "include": [
                            "refs/pull/**",
                        ],
                    },
                },
            },
            {
                "name": "docker",
                "image": "plugins/docker:latest",
                "pull": "always",
                "settings": {
                    "username": {
                        "from_secret": "docker_username",
                    },
                    "password": {
                        "from_secret": "docker_password",
                    },
                    "auto_tag": True,
                    "auto_tag_suffix": "linux-%s" % (arch),
                    "dockerfile": "docker/Dockerfile.linux.%s" % (arch),
                    "repo": ctx.repo.slug,
                },
                "when": {
                    "ref": {
                        "exclude": [
                            "refs/pull/**",
                        ],
                    },
                },
            },
        ],
        "volumes": [
            {
                "name": "gopath",
                "temp": {},
            },
        ],
        "depends_on": [
            "testing",
        ],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/tags/**",
                "refs/pull/**",
            ],
        },
    }

def binary(ctx, name):
    # uploads binary to https://download.owncloud.com/ocis/migration/testing/
    target = "/ocis/%s/testing" % (ctx.repo.name.replace("ocis-", ""))
    if ctx.build.event == "tag":
        # uploads binary to eg. https://download.owncloud.com/ocis/migration/1.0.0-beta9/
        target = "/ocis/%s/%s" % (ctx.repo.name.replace("ocis-", ""), ctx.build.ref.replace("refs/tags/v", ""))

    settings = {
        "endpoint": {
            "from_secret": "upload_s3_endpoint",
        },
        "access_key": {
            "from_secret": "upload_s3_access_key",
        },
        "secret_key": {
            "from_secret": "upload_s3_secret_key",
        },
        "bucket": {
            "from_secret": "upload_s3_bucket",
        },
        "path_style": True,
        "strip_prefix": "dist/release/",
        "source": "dist/release/*",
        "target": target,
    }

    return {
        "kind": "pipeline",
        "type": "docker",
        "name": name,
        "platform": {
            "os": "linux",
            "arch": "amd64",
        },
        "steps": [
            {
                "name": "generate",
                "image": "webhippie/golang:1.13",
                "pull": "always",
                "commands": [
                    "make generate",
                ],
                "volumes": [
                    {
                        "name": "gopath",
                        "path": "/srv/app",
                    },
                ],
            },
            {
                "name": "build",
                "image": "webhippie/golang:1.13",
                "pull": "always",
                "commands": [
                    "make release-%s" % (name),
                ],
                "volumes": [
                    {
                        "name": "gopath",
                        "path": "/srv/app",
                    },
                ],
            },
            {
                "name": "finish",
                "image": "webhippie/golang:1.13",
                "pull": "always",
                "commands": [
                    "make release-finish",
                ],
                "volumes": [
                    {
                        "name": "gopath",
                        "path": "/srv/app",
                    },
                ],
            },
            {
                "name": "upload",
                "image": "plugins/s3:1",
                "pull": "always",
                "settings": settings,
                "when": {
                    "ref": [
                        "refs/heads/master",
                        "refs/tags/**",
                    ],
                },
            },
            {
                "name": "changelog",
                "image": "toolhippie/calens:latest",
                "pull": "always",
                "commands": [
                    "calens --version %s -o dist/CHANGELOG.md" % ctx.build.ref.replace("refs/tags/v", "").split("-")[0],
                ],
                "when": {
                    "ref": [
                        "refs/tags/**",
                    ],
                },
            },
            {
                "name": "release",
                "image": "plugins/github-release:1",
                "pull": "always",
                "settings": {
                    "api_key": {
                        "from_secret": "github_token",
                    },
                    "files": [
                        "dist/release/*",
                    ],
                    "title": ctx.build.ref.replace("refs/tags/v", ""),
                    "note": "dist/CHANGELOG.md",
                    "overwrite": True,
                    "prerelease": len(ctx.build.ref.split("-")) > 1,
                },
                "when": {
                    "ref": [
                        "refs/tags/**",
                    ],
                },
            },
        ],
        "volumes": [
            {
                "name": "gopath",
                "temp": {},
            },
        ],
        "depends_on": [
            "testing",
        ],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/tags/**",
                "refs/pull/**",
            ],
        },
    }

def manifest(ctx):
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "manifest",
        "platform": {
            "os": "linux",
            "arch": "amd64",
        },
        "steps": [
            {
                "name": "execute",
                "image": "plugins/manifest:1",
                "pull": "always",
                "settings": {
                    "username": {
                        "from_secret": "docker_username",
                    },
                    "password": {
                        "from_secret": "docker_password",
                    },
                    "spec": "docker/manifest.tmpl",
                    "auto_tag": True,
                    "ignore_missing": True,
                },
            },
        ],
        "depends_on": [
            "docker-amd64",
            "docker-arm64",
            "docker-arm",
            "linux",
            "darwin",
            "windows",
        ],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/tags/**",
            ],
        },
    }

def changelog(ctx):
    repo_slug = ctx.build.source_repo if ctx.build.source_repo else ctx.repo.slug
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "changelog",
        "platform": {
            "os": "linux",
            "arch": "amd64",
        },
        "clone": {
            "disable": True,
        },
        "steps": [
            {
                "name": "clone",
                "image": "plugins/git-action:1",
                "pull": "always",
                "settings": {
                    "actions": [
                        "clone",
                    ],
                    "remote": "https://github.com/%s" % (repo_slug),
                    "branch": ctx.build.source if ctx.build.event == "pull_request" else "master",
                    "path": "/drone/src",
                    "netrc_machine": "github.com",
                    "netrc_username": {
                        "from_secret": "github_username",
                    },
                    "netrc_password": {
                        "from_secret": "github_token",
                    },
                },
            },
            {
                "name": "generate",
                "image": "webhippie/golang:1.13",
                "pull": "always",
                "commands": [
                    "make changelog",
                ],
            },
            {
                "name": "diff",
                "image": "owncloudci/alpine:latest",
                "pull": "always",
                "commands": [
                    "git diff",
                ],
            },
            {
                "name": "output",
                "image": "owncloudci/alpine:latest",
                "pull": "always",
                "commands": [
                    "cat CHANGELOG.md",
                ],
            },
            {
                "name": "publish",
                "image": "plugins/git-action:1",
                "pull": "always",
                "settings": {
                    "actions": [
                        "commit",
                        "push",
                    ],
                    "message": "Automated changelog update [skip ci]",
                    "branch": "master",
                    "author_email": "devops@owncloud.com",
                    "author_name": "ownClouders",
                    "netrc_machine": "github.com",
                    "netrc_username": {
                        "from_secret": "github_username",
                    },
                    "netrc_password": {
                        "from_secret": "github_token",
                    },
                },
                "when": {
                    "ref": {
                        "exclude": [
                            "refs/pull/**",
                        ],
                    },
                },
            },
        ],
        "depends_on": [
            "manifest",
        ],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/pull/**",
            ],
        },
    }

def readme(ctx):
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "readme",
        "platform": {
            "os": "linux",
            "arch": "amd64",
        },
        "steps": [
            {
                "name": "execute",
                "image": "chko/docker-pushrm:1",
                "pull": "always",
                "environment": {
                    "DOCKER_USER": {
                        "from_secret": "docker_username",
                    },
                    "DOCKER_PASS": {
                        "from_secret": "docker_password",
                    },
                    "PUSHRM_TARGET": "owncloud/${DRONE_REPO_NAME}",
                    "PUSHRM_SHORT": "Docker images for %s" % (ctx.repo.name),
                    "PUSHRM_FILE": "README.md",
                },
            },
        ],
        "depends_on": [
            "changelog",
        ],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/tags/**",
            ],
        },
    }

def website(ctx):
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "website",
        "platform": {
            "os": "linux",
            "arch": "amd64",
        },
        "steps": [
            {
                "name": "prepare",
                "image": "owncloudci/alpine:latest",
                "commands": [
                    "make docs-copy",
                ],
            },
            {
                "name": "test",
                "image": "owncloudci/hugo:0.71.0",
                "commands": [
                    "cd hugo",
                    "hugo",
                ],
            },
            {
                "name": "list",
                "image": "owncloudci/alpine:latest",
                "commands": [
                    "tree hugo/public",
                ],
            },
            {
                "name": "publish",
                "image": "plugins/gh-pages:1",
                "pull": "always",
                "settings": {
                    "username": {
                        "from_secret": "github_username",
                    },
                    "password": {
                        "from_secret": "github_token",
                    },
                    "pages_directory": "docs/",
                    "target_branch": "docs",
                },
                "when": {
                    "ref": {
                        "exclude": [
                            "refs/pull/**",
                        ],
                    },
                },
            },
            {
                "name": "downstream",
                "image": "plugins/downstream",
                "settings": {
                    "server": "https://drone.owncloud.com/",
                    "token": {
                        "from_secret": "drone_token",
                    },
                    "repositories": [
                        "owncloud/owncloud.github.io@source",
                    ],
                },
                "when": {
                    "ref": {
                        "exclude": [
                            "refs/pull/**",
                        ],
                    },
                },
            },
        ],
        "depends_on": [
            "readme",
        ],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/pull/**",
            ],
        },
    }
