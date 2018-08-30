## How to deploy nailed on kubernetes

`kubectl create secret generic nailed-oscrc --from-file=$OSCRC`

`kubectl create secret generic nailed-netrc --from-file=$NETRC`

Edit `config.yml` in `nailed_configmaps.yml` according to your needs.
An example config can be found in `/config/config.yml.example`.
Afterwards create the configMaps with:

`kubectl apply -f nailed_configmaps.yml`

`kubectl apply -f nailed_volume.yml`

Make sure that an empty file called `nailed_0.db` does exist in your
hostpath directory on the host. 

`kubectl apply -f nailed_cronjob.yml`

the cronjob will sync the database once per hour.

`kubectl create job run-once --from=cronjob/nailed-refresh`

Wait until the cronjob has finished before proceeding. 

`kubectl apply -f nailed_deployment.yml`
