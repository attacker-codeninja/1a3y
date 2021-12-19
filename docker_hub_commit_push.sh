# save installed tools and state
docker commit hungry_visvesvaraya
docker commit -m "Commit stopped container" hungry_visvesvaraya storenth/1a3y-axiom:v1.1

docker tag <NEW_IMAGE_ID> storenth/1a3y-axiom:1a3y.v1.0
docker push storenth/1a3y-axiom:1a3y.v1.0

# pull and local run
docker pull storenth/1a3y-axiom:1a3y.v1.1
docker run -d -it storenth/1a3y-axiom:v1.1 
docker exec -it <NEW_CONTAINER_ID> bash