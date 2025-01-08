CLUSTER_NAME=ginflix
VID_NAME=stock_analysis.mp4
WEB_FILE=web.yaml
DATABASE_FILE=database.yaml
STREAMER_FILE=streamer.yaml

### KIND CLUSTER CONFIG ###
cluster-create:
	- kind create cluster --name ${CLUSTER_NAME} --config kind-config.yml --image kindest/node:v1.31.4
	- kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/tigera-operator.yaml
	- kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/custom-resources.yaml
cluster-delete:
	kind delete clusters ${CLUSTER_NAME}
### END OF KIND CLUSTER CONFIG ###

### APPLICATION CONFIG ###
metallb:
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
	kubectl apply -f loadbalancer/iprange.yml
	kubectl apply -f loadbalancer/l2advertisement.yml
_metallb:
	- kubectl delete -f loadbalancer/iprange.yml
	- kubectl delete -f loadbalancer/l2advertisement.yml
database:
	kubectl apply -f volumes/database.yml
	kubectl apply -f deployments/database.yml
	kubectl apply -f services/database.yml
_database:
	- kubectl delete -f deployments/database.yml
	- kubectl delete -f volumes/database.yml
	- kubectl delete -f services/database.yml
streamer:
	kubectl apply -f volumes/streamer.yml
	kubectl apply -f deployments/streamer.yml
	kubectl apply -f services/streamer.yml
_streamer:
	- kubectl delete -f deployments/streamer.yml
	- kubectl delete -f volumes/streamer.yml
	- kubectl delete -f services/streamer.yml
web:
	kubectl wait --for=condition=ready pod/$$(kubectl get pods --no-headers | awk -F' ' '{print $$1'} | grep database) --timeout=300s
	kubectl apply -f deployments/web.yml
	kubectl apply -f services/web.yml
_web:
	- kubectl delete -f deployments/web.yml
	- kubectl delete -f services/web.yml
caddy:
	{ \
		cd reverse-proxy ; \
		docker compose up -d ; \
	}
down-caddy:
	{\
		cd reverse-proxy ; \
		docker compose down ; \
	}
_caddy:
	{\
		cd reverse-proxy ; \
		docker compose down --rmi all ; \
	}
STREAMER:=$(shell kubectl get pods -l run=streamer | awk -F' ' 'NR==2 {print $$1}')
copy:
	kubectl cp videos/${VID_NAME} $(STREAMER):/var/www/html/stock.mp4
	kubectl exec -ti $(STREAMER) -- ls /var/www/html/
### END OF APPLICATION CONFIG ###

clean: stop cluster-delete

### KUBESCAPE CONFIG ###
kubescape:
	curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash
full-scan:
ifndef SCAN_NAME
	@echo "Error: env var SCAN_NAME is not set. Please set it and try again." >&2
	@exit 1
endif
	kubescape scan -f html > scans/full/$(SCAN_NAME).html
	kubescape scan -f pdf > scans/full/$(SCAN_NAME).pdf
	kubescape scan -f pretty-printer > scans/full/$(SCAN_NAME).pretty-printer
web-scan:
ifndef SCAN_NAME
	@echo "Error: env var SCAN_NAME is not set. Please set it and try again." >&2
	@exit 1
endif
	kubescape scan workload deployments/web --namespace default --format html > scans/web/$(SCAN_NAME).html
	kubescape scan workload deployments/web --namespace default --format pdf > scans/web/$(SCAN_NAME).pdf
	kubescape scan workload deployments/web --namespace default --format pretty-printer > scans/web/$(SCAN_NAME).pretty-printer
streamer-scan:
ifndef SCAN_NAME
	@echo "Error: env var SCAN_NAME is not set. Please set it and try again." >&2
	@exit 1
endif
	kubescape scan workload deployments/streamer --namespace default --format html > scans/streamer/$(SCAN_NAME).html
	kubescape scan workload deployments/streamer --namespace default --format pdf > scans/streamer/$(SCAN_NAME).pdf
	kubescape scan workload deployments/streamer --namespace default --format pretty-printer > scans/streamer/$(SCAN_NAME).pretty-printer
database-scan:
ifndef SCAN_NAME
	@echo "Error: env var SCAN_NAME is not set. Please set it and try again." >&2
	@exit 1
endif
	kubescape scan workload deployments/database --namespace default --format html > scans/database/$(SCAN_NAME).html
	kubescape scan workload deployments/database --namespace default --format pdf > scans/database/$(SCAN_NAME).pdf
	kubescape scan workload deployments/database --namespace default --format pretty-printer > scans/database/$(SCAN_NAME).pretty-printer
scan: web-scan streamer-scan database-scan
### END OF KUBESCAPE CONFIG ###


### SECURITY BEST PRACTICES ###
##### Putting credentials in secrets #####
SECRETS_FOLDER='secrets'
web-secrets:
	if ! kubectl get secret web-secrets ; then kubectl create secret generic web-secrets --from-env-file=$(SECRETS_FOLDER)/web-secrets.env ; fi
_web-secrets:
	- kubectl delete secrets web-secrets
database-secrets:
	if ! kubectl get secret database-secrets ; then kubectl create secret generic database-secrets --from-env-file=$(SECRETS_FOLDER)/database-secrets.env ; fi
_database-secrets:
	- kubectl delete secrets database-secrets
secrets: database-secrets web-secrets
_secrets: _web-secrets _database-secrets

##### End of putting credentials in secrets #####

##### Network policies #####
NP_FOLDER=network-policies
web-np:
	kubectl apply -f $(NP_FOLDER)/$(WEB_FILE)
_web-np:
	- kubectl delete -f $(NP_FOLDER)/$(WEB_FILE)
database-np:
	kubectl apply -f $(NP_FOLDER)/$(DATABASE_FILE)
_database-np:
	- kubectl delete -f $(NP_FOLDER)/$(DATABASE_FILE)
streamer-np:
	kubectl apply -f $(NP_FOLDER)/$(STREAMER_FILE)
_streamer-np:
	- kubectl delete -f $(NP_FOLDER)/$(STREAMER_FILE)
np: web-np database-np streamer-np
_np: _web-np _database-np _streamer-np
##### End of Network policies #####
##### Service Accounts #####
SA_FOLDER=service-accounts
web-sa:
	kubectl apply -f $(SA_FOLDER)/$(WEB_FILE)
_web-sa:
	- kubectl delete -f $(SA_FOLDER)/$(WEB_FILE)
database-sa:
	kubectl apply -f $(SA_FOLDER)/$(DATABASE_FILE)
_database-sa:
	- kubectl delete -f $(SA_FOLDER)/$(DATABASE_FILE)
streamer-sa:
	kubectl apply -f $(SA_FOLDER)/$(STREAMER_FILE)
_streamer-sa:
	- kubectl delete -f $(SA_FOLDER)/$(STREAMER_FILE)
sa: web-sa database-sa streamer-sa
_sa: _web-sa _database-sa _streamer-sa
##### End of Service Accounts #####
##### RBAC #####
RBAC_FOLDER=roles
web-rbac:
	kubectl apply -f $(RBAC_FOLDER)/$(WEB_FILE)
_web-rbac:
	- kubectl delete -f $(RBAC_FOLDER)/$(WEB_FILE)
database-rbac:
	kubectl apply -f $(RBAC_FOLDER)/$(DATABASE_FILE)
_database-rbac:
	- kubectl delete -f $(RBAC_FOLDER)/$(DATABASE_FILE)
streamer-rbac:
	kubectl apply -f $(RBAC_FOLDER)/$(STREAMER_FILE)
_streamer-rbac:
	- kubectl delete -f $(RBAC_FOLDER)/$(STREAMER_FILE)
rbac: web-rbac database-rbac streamer-rbac
_rbac: _web-rbac _database-rbac _streamer-rbac
##### End of RBAC #####
### END OF SECURITY BEST PRACTICES ###

### LAUNCHING THE APPLICATION ###
launch: sa secrets metallb database streamer web caddy np rbac
start:
	while ! make launch ; do echo "Retrying..." ; sleep 20 ; done
stop: _secrets _metallb _database _streamer _web _caddy _np _sa _rbac
### END OF LAUNCHING THE APPLICATION ###