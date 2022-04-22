kind: Deployment
replicaCount: 1
rbac:
  create: false
config:
  service: |
    [SERVICE]
        Flush 5
        Daemon Off
        Log_Level debug
        HTTP_Server On
        HTTP_Listen 0.0.0.0
        HTTP_Port 2020
  inputs: |
    [INPUT]
        Name dummy
        Tag dummy.log
        Dummy {"message": "testing"}
        Rate 10
  outputs: |
    [OUTPUT]
        Name opensearch
        Match *
        Host ${HOSTED_OPENSEARCH_HOST}
        Port ${HOSTED_OPENSEARCH_PORT}
        Index fluentbit
        tls On
        tls.verify Off
        http_user admin
        http_passwd ${HOSTED_OPENSEARCH_PASSWORD}

