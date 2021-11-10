# This project is unmaintained! Use at your own risk.

## What is nailed?

`nailed` consists of a back-end CLI for data collection and a sinatra based web front-end for visualization of relevant development data of Products that have their bugtracker on Bugzilla and (optionally) their codebase on GitHub.

`Be aware` that the bugzilla layout (metadata) is still SUSE specific, which may not be useful for everybody.
e.g. it relies on bugs being tagged as L3. The plan is to make it optional in the future.

## How does it look like?

![alt tag](https://github.com/MaximilianMeister/maximilianmeister.github.io/raw/master/pics/nailed_overview.png)
![alt tag](https://github.com/MaximilianMeister/maximilianmeister.github.io/raw/master/pics/nailed_bugzilla.png)
![alt tag](https://github.com/MaximilianMeister/maximilianmeister.github.io/raw/master/pics/nailed_github.png)

## Installation using git (recommended)
You can use nailed directly from a git checkout as well. Make sure to fetch the dependencies and call `nailed` from the `bin` directory.
### SUSE
```
zypper in ruby ruby-devel ruby2.5-rubygem-bundler gcc gcc-c++ libz1 zlib-devel sqlite3 sqlite3-devel

bundle install
```

* for the SUSE BugZilla API make sure you have an `.oscrc` file with your credentials in ~

## Usage

```
$ nailed -h
Options:
          --new, -n:   Create new database 
      --migrate, -m:   Migrate/Upgrade database
     --bugzilla, -b:   Refresh bugzilla database records
       --github, -g:   Refresh github database records
     --list, -l <s>:   List github repositories within organization
       --server, -s:   Start a dashboard webinterface
         --help, -h:   Show this message
```

## Private GitHub repos

* for the github API make sure you have a `.netrc` with a valid GitHub OAuth-Token in ~

```
# example .netrc

machine api.github.com
  login MaximilianMeister
  password <your OAuth Token>
```

## Configuration

All configuration is read from [config/config.yml](https://raw.githubusercontent.com/openSUSE/nailed/master/config/config.yml.example)

* configure your [config/config.yml](https://raw.githubusercontent.com/openSUSE/nailed/master/config/config.yml.example)
* to setup the database run

```
nailed --migrate
```

## Changes in production

* in production, after adding products/changes, to upgrade the database with the new changes run

```
nailed --migrate
```

* make sure to fetch new data with

```
nailed --bugzilla
nailed --github
```

* restart the webserver

## Run

* create a `cronjob` for automated data collection with `nailed`
  
  e.g. `0 * * * * cd /path/to/bin/nailed; ./nailed -b && ./nailed -g`

* start the webserver with `nailed --server`

## Running as a Docker container

* Build the image

```
git clone https://github.com/MaximilianMeister/nailed
cd nailed
docker build -t nailed:latest .
```

* Create a directory to hold the data, and create the config subdirectory

```
mkdir -p /tmp/storage/config
```

Add `~/.netrc` when you want to collect data from a private GitHub repo, `config/colors.yml` `config/config.yml`, and if you are from SUSE `~/.oscrc` into `/tmp/storage/config`.

For trying out Nailed, just use [test/config.yml](https://raw.githubusercontent.com/openSUSE/nailed/master/test/config.yml)

That directory will be mounted as the /nailed/data volume in the container.

```
docker run -ti -v /tmp/storage:/nailed/data -p 8000:4567 nailed:latest
```

## Credits

* [Duncan Mac-Vicar P.](https://github.com/dmacvicar) for the awesome [Bicho](https://github.com/dmacvicar/bicho) gem.
