[![Build Status](https://github.com/cloudtruth/importer/workflows/CD/badge.svg)](https://github.com/cloudtruth/importer/actions)
[![Coverage Status](https://codecov.io/gh/cloudtruth/importer/branch/main/graph/badge.svg)](https://codecov.io/gh/cloudtruth/importer)
[![Configured by CloudTruth](https://img.shields.io/badge/configured--by-CloudTruth-blue.svg?style=plastic&labelColor=384047&color=00A6C0&link=https://cloudtruth.com)](https://cloudtruth.com)

# Cloudtruth Importer

An importer utility for adding parameters to cloudtruth.

## Installation

```shell
docker pull cloudtruth/importer
```

## Uninstall

```shell
docker rmi --force cloudtruth/importer
```

## Usage

To get the cli usage for the importer:

```shell
docker run cloudtruth/importer --help
```

and then run it for real like: 

```shell
docker run -v $(pwd):/data -e CLOUDTRUTH_API_KEY=xyz cloudtruth/importer --dry-run /data/some/file.yaml
```

It scans the given directories and files (or stdin), parsing those that are a
form of structured data (json/yaml/dotenv).  The structured data is then passed
into a transformation template in order to generate parameter definitions that
are used to drive the cloudtruth cli to create the actual parameters.

The transformation template is processed using the [Liquid template
language](https://shopify.github.io/liquid/).  The context supplied to each
rendering of the template will contain the variables:

| Variable | Description | Type |
|----------|-------------|------|
| environment | The environment supplied from the `--environment` cli flag or by using a named capture from `--path-selector` (i.e. to extract the environment from filenames) | string |
| project | The project supplied from the `--project` cli flag or by using a named capture from `--path-selector` (i.e. to extract the environment from filenames) | string |
| filename | The filename for the data the template is currently being rendered for | string |
| data | The structured data parsed from the file that the template is currently being rendered for | map or array depending on file contents |
| <named_capture> | Any named captures from applying the `--path-selector` regular expression to the filename | string

The default transformation template treats the `data` passed in as a simple HashMap,
using its keys/value to be the parameter keys and values.  It looks like:

```liquid
{% for entry in data %}
- environment: "{{ environment }}"
  project: "{{ project }}"
  key: "{{ entry[0] }}"
  value: "{{ entry[1] }}"
{% endfor %}
```

To handle other data structures, your template should produce a yaml document
that is a list of parameter definitions of the form:

```yaml
 - environment: someEnvironment,  # The environment to set the value for
   project: someProject, # The project to create the parameter in
   key: aKey, # The key name of the parameter
   value: aValue, # The value for the parameter.  Don't set this if using FQN+JMES
   secret: false, # (optional) Indicate that the parameter should be created as a secret
   fqn: myFQN, # (optional) Set the parameter value to come from the given FQN+JMES
   jmes: myJmesPath # (optional) Set the parameter value to come from the given FQN+JMES
```

### Examples

#### Read from stdin

```shell
cat somefile.yaml | docker run -i -e CLOUDTRUTH_API_KEY=xyz cloudtruth/importer --dry-run --stdin yaml
```

## Development

After checking out the repo, run `docker build -t cloudtruth/importer .` to build the image.

Run `docker run -it --entrypoint "" cloudtruth/importer bundle exec rspec` to run the tests.

Run `docker run -it --entrypoint "" cloudtruth/importer bundle exec bin/console` to get an interactive console.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/cloudtruth/importer.
