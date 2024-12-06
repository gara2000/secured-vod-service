CLUSTER_NAME=ginflix
VID_NAME=stock_analysis.mp4

### KIND CLUSTER CONFIG ###
cluster-create:
	- kind create cluster --name ${CLUSTER_NAME} --config kind-config.yml
	- kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/tigera-operator.yaml
	- kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/custom-resources.yaml
cluster-delete:
	kind delete clusters ${CLUSTER_NAME}
### END OF KIND CLUSTER CONFIG ###

### APPLICATION ###
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
launch: metallb database streamer web caddy 
start:
	while ! make launch ; do echo "Retrying..." ; sleep 20 ; done
stop: _metallb _database _streamer _web _caddy
### END OF APPLICATION ###

clean: stop cluster-delete

### KUBESCAPE CONFIG ###
kubescape:
	curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash
scan:
	kubescape scan -f html > scans/new_scan.html
### END OF KUBESCAPE CONFIG ###


### SECURITY BEST PRACTICES ###
##### Putting credentials in secrets #####
web-secrets:
	kubectl create secret generic web-secrets --from-env-file=web-secrets.env
database-secrets:
	kubectl create secret generic database-secrets --from-env-file=database-secrets.env
secrets: databse-secrets web-secrets
##### End of putting credentials in secrets #####
### END OF SECURITY BEST PRACTICES ###