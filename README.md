# h5ai-docker
Alpine-based container with Nginx 1.25, PHP 8.1, hosting h5ai 0.30.0.

docker-compose
```yaml
---
version: "3.9"
services:
  h5ai:
    container_name: h5ai
    image: docker.io/sushibox/h5ai:latest
    restart: always
    ports:
      - "8000:80"
    volumes:
      - "/opt/h5ai/h5ai:/h5ai"
      - "/opt/h5ai/config:/config"
```
