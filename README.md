[![Code Climate](https://codeclimate.com/github/MaximilianMeister/nailed/badges/gpa.svg)](https://codeclimate.com/github/MaximilianMeister/nailed)
## What is nailed?

`nailed` consists of a back-end CLI for data collection and a sinatra based web front-end for visualization of relevant development data of Products that have their bugtracker on Bugzilla and (optionally) their codebase on GitHub and their CI on Jenkins.

`Be aware` that the bugzilla layout (metadata) is still SUSE specific, which may not be useful for everybody.
e.g. it relies on bugs being tagged as L3. The plan is to make it optional in the future.

## How does it look like?

![alt tag](https://github.com/MaximilianMeister/maximilianmeister.github.io/blob/master/pics/nailed_overview.png)
![alt tag](https://github.com/MaximilianMeister/maximilianmeister.github.io/blob/master/pics/nailed_bugzilla.png)
![alt tag](https://github.com/MaximilianMeister/maximilianmeister.github.io/blob/master/pics/nailed_github.png)
![alt tag](https://github.com/MaximilianMeister/maximilianmeister.github.io/blob/master/pics/nailed_jenkins.png)

## Installation using gem
`gem install 'nailed'`

Note that this is always a bit outdated.

## Installation using git (recommended)
You can use nailed directly from a git checkout as well. Make sure to fetch the dependencies and call `nailed` from the `bin` directory.
### SUSE
```
zypper in libxml2-devel sqlite3-devel gcc make ruby-devel
bundle install
```

## Usage

```
$ nailed -h
Options:
      --migrate, -m:   Migrate/Upgrade database
     --bugzilla, -b:   Refresh bugzilla database records
       --github, -g:   Refresh github database records
      --jenkins, -j:   Refresh jenkins database records
     --list, -l <s>:   List github repositories within organization
       --server, -s:   Start a dashboard webinterface
         --help, -h:   Show this message
```

## Initial setup

* for the bugzilla API make sure you have an `.oscrc` file with your credentials in ~
* for the github API make sure you have a `.netrc` with a valid GitHub OAuth-Token in ~
```
# example .netrc

machine api.github.com
  login MaximilianMeister
  password <your OAuth Token>
```
* configure your [config/config.yml](./config/config.yml)
* to setup the database run
```
nailed --migrate
```

## Configuration

All configuration is read from [config/config.yml](./config/config.yml)

## Changes in production

* in production, after adding products/changes, to upgrade the database with the new changes run
```
nailed --migrate
```
* make sure to fetch new data with
```
nailed --bugzilla
nailed --github
nailed --jenkins
```
* restart the webserver

## Run

* create a `cronjob` for automated data collection with `nailed`
* start the webserver with `nailed --server`

## Running as a Docker container

* Build the image

```
$ git clone https://github.com/MaximilianMeister/nailed
$ cd nailed
$ docker build -t nailed:latest .
```

* Create a directory to hold the data, and create the config, db and log subdirectories

```
mkdir -p /mystorage/config
mkdir -p /mystorage/log
mkdir -p /mystorage/db
```

Add .oscrc and netrc and config.yml into /mystorage/config. You can as well add colors.yml
here and override some defaults.
You need to mount that directory as the /data volume in the container.

* Migrate and fetch initial data

```
docker run -ti -v /mystorage:/data nailed:latest --migrate
```

* Run the server

In this case, we map it to port 8000 on the host

```
docker run -ti -v /mystorage:/data -p 8000:4567 nailed:latest --server
```

## Credits

* [Duncan Mac-Vicar P.](https://github.com/dmacvicar) for the awesome [Bicho](https://github.com/dmacvicar/bicho) gem.
