## What is nailed?

`nailed` consists of a back-end CLI for data collection and a sinatra based web front-end for visualization of relevant development data of the SUSE Cloud Product.

## Usage

```
$ nailed -h
Options:
      --migrate, -m:   Set database to pristine state
      --upgrade, -u:   Upgrade database
  --product, -p <s>:   Specify a product
          --add, -a:   Add a new product to the database
       --remove, -r:   Remove a product from the database
     --bugzilla, -b:   Refresh bugzilla database records
       --github, -g:   Refresh github database records
           --l3, -l:   Refresh l3 trend database records
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
* run `nailed -m` to setup the database
