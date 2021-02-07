docker build -t voules/multi-client:latest -t voules/multi-client:$SHA -f ../complex/client/Dockerfile ../complex/client
docker build -t voules/multi-server:latest -t voules/multi-server:$SHA -f ../complex/server/Dockerfile ../complex/server
docker build -t voules/multi-worker:latest -t voules/multi-worker:$SHA -f ../complex/worker/Dockerfile ../complex/worker

docker push voules/multi-client:latest
docker push voules/multi-server:latest
docker push voules/multi-worker:latest

docker push voules/multi-client:$SHA
docker push voules/multi-server:$SHA
docker push voules/multi-worker:$SHA