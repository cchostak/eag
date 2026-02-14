FROM ghcr.io/agentgateway/agentgateway:0.12.0

COPY config.yaml /etc/agentgateway/config.yaml

EXPOSE 3000 4000 5000 15000 15001 15002

ENTRYPOINT ["agentgateway", "-f", "/etc/agentgateway/config.yaml"]
