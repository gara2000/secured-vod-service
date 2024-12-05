CLUSTER_NAME=ginflix
VID_NAME=stock_analysis.mp4

cluster-create:
	# - kind create cluster --name ${CLUSTER_NAME} --config kind-config.yml --image="kindest/node:v1.23.10@sha256:f047448af6a656fae7bc909e2fab360c18c487ef3edc93f06d78cdfd864b2d12"
	- kind create cluster --name ${CLUSTER_NAME} --config kind-config.yml
	- kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/tigera-operator.yaml
	- kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/custom-resources.yaml

cluster-delete:
	kind delete clusters ${CLUSTER_NAME}

loadbalancer:
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
	kubectl apply -f k8s-loadbalancer/iprange.yml
	kubectl apply -f k8s-loadbalancer/l2advertisement.yml

_loadbalancer:
	- kubectl delete -f k8s-loadbalancer/iprange.yml
	- kubectl delete -f k8s-loadbalancer/l2advertisement.yml

database:
	kubectl apply -f k8s-volumes/database.yml
	kubectl apply -f k8s-deployments/database.yml
	kubectl apply -f k8s-services/database.yml
_database:
	- kubectl delete -f k8s-deployments/database.yml
	- kubectl delete -f k8s-volumes/database.yml
	- kubectl delete -f k8s-services/database.yml

streamer:
	kubectl apply -f k8s-volumes/streamer.yml
	kubectl apply -f k8s-deployments/streamer.yml
	kubectl apply -f k8s-services/streamer.yml
_streamer:
	- kubectl delete -f k8s-deployments/streamer.yml
	- kubectl delete -f k8s-volumes/streamer.yml
	- kubectl delete -f k8s-services/streamer.yml

web:
	kubectl wait --for=condition=ready pod/$$(kubectl get pods --no-headers | awk -F' ' '{print $$1'} | grep database) --timeout=300s
	kubectl apply -f k8s-deployments/web.yml
	kubectl apply -f k8s-services/web.yml
_web:
	- kubectl delete -f k8s-deployments/web.yml
	- kubectl delete -f k8s-services/web.yml

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

launch: loadbalancer database streamer web caddy
start:
	while ! make launch ; do echo "Retrying..." ; sleep 20 ; done
stop: _loadbalancer _database _streamer _web _caddy

clean: stop cluster-delete

web-secrets:
	kubectl create secret generic web-secrets --from-env-file=web-secrets.env
database-secrets:
	kubectl create secret generic database-secrets --from-env-file=database-secrets.env
secrets: databse-secrets web-secrets
