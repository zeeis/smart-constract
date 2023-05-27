```shell

docker-compose up
docker network ls
vim /opt/aptos/var/validator_note_template.yaml
vim docker_compose.yaml
docker volume ls
docker volume inspect aws-validator_aptos-shared

cat /home/ubuntu/aws-validator/docker-compose.yaml
cat /home/ubuntu/aws-validator/validator_node_template.yaml

/var/lib/docker/volumes/aws-validator_aptos-shared/_data/validator.log
/var/lib/docker/volumes/aws-validator_aptos-shared/_data/0/db/<consensusdb|ledger_db|state_merkle>/LOG
/var/lib/docker/volumes/aws-validator_aptos-shared/_data/0/db/<consensusdb|ledger_db|state_merkle>/LOG.old.<timestamp>
/var/lib/docker/volumes/aws-validator_aptos-shared/_data/0/db/<consensusdb|ledger_db|state_merkle>/<num>.log
/var/lib/docker/volumes/aws-validator_aptos-shared/_data/0/db/<consensusdb|ledger_db|state_merkle>/<num>.sst

```
