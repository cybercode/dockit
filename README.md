[docker-api]: https://github.com/swipely/docker-api

# Dockit
`Dockit` is an alternative composer for docker projects. It's (IMHO) advantaoge is that it is scriptable, and rather than a single yaml configuration file, each service has it's own configuration file (`Dockit.yaml`), as well as an optional `Dockit.rb` which can provide scriptable configuration (as `Thor` subcommands) for any phase of the build and deploy process.

`Dockit` is built on the [Thor](https://github.com/erikhuda/thor) cli and the
[docker-api] libraries.

## Installation
``` sh
$ gem install dockit
```

## Usage
1. Create a top level deployment directory
2. Create a sub-directory for each service
3. Create a `Dockit.yaml` for each service (and optionally a `Docit.rb`.)
4. Optionally, create a top level `Dockit.rb` subcommand file to orchestrate the build and deployment of the services.
5. Run `dockit` in the root directory for help.

##  `Dockit.yaml`

The sections of the config file map directly to the argument sent by the
[docker-api] to the corresponding api endpoints (see  [docker api](http://docs.docker.com/reference/api/docker_remote_api_v1.9/).)

The top level sections are:

- `build`
- `create`
- `run`

At least one of the sections `build` or `create` are required. If their is no `build` section, the `create` section must specify an `Image` value. Note that most (all?) of the values specified in the `run` section can be specified in the `create: HostConfig:` instead.

### Examples

#### Simple build

```yaml
build:
  t: my-image
```

Executing `dockit build` in the directory containing the file above, will create an image from the `Dockerfile` in the same directory named my-image.

Then executing `dockit start` will create and run a container named `my-image`

[docker hub]: https://registry.hub.docker.com/search?q=library

#### Pre-generated (or [docker hub]) image
```yaml
create:
  Image: postgres
  name: db
```

Executing `dockit build` will do nothing. Executing `dockit start` will start run a container named `db` from the local (or [docker hub] postgresql image.

#### Using locals and environment variables

The yaml file is first processed by the `ERB` template library. The "bindings" passed to the template processor can be specified on the command line with the `--locals` (alias `-l`) option. Also, the command line option `--env` (alias `-e`) is passed as `-<env>` For example, given:

```yaml
create:
  Image: postgres
  name: db<%= env %>
  Env:
  - MYVAR=<%= myval %>
```

- `dockit start` will generate an error (myval not defined)
- `dockit start -l myval:foo` will start a container named `db` with the environment variable `MVAR` set to `foo`.
- `dockt start -l myval:foo -e test` will start a container named `db-test`

## `Dockit.rb`

The `dockit.rb` file can be used to add new subcommands to the cli on a project-wide or per-service basis. For per-service subcommands, the defined class name should be the "classified" directory name, for the project-wide, it should be named `All`. If the class inherits from `SubCommand` instead of `Thor`, it will inherit two useful methods:

- `invoke_default(service)` will run the same-named (or specified) dockit command on the specified service.
- `invoke_service(service)` will run the same-named (or specifed) subcommand from the `Dockit.rb` for the specified service.

For example:

```ruby
class All < SubCommand
  desc 'build', 'build all images'
  def build
    invoke_service 'app'
    invoke_default 'db'
  end
end
```

Would run the `build` method from the file `app/Dockit.rb` and the create an image using the options from `db/Dockit.yaml`.

## The Github boilerplate
### Development
After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Contributing
1. Fork it ( https://github.com/cybercode/dockit/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am [comment]`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
