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
        Match *
        Name azure_kusto
        Tenant_Id ${AZURE_KUSTO_TENANT_ID}
        Client_Id ${AZURE_KUSTO_CLIENT_ID}
        Client_Secret ${AZURE_KUSTO_CLIENT_SECRET}
        Ingestion_Endpoint ${AZURE_KUSTO_INGESTION_ENDPOINT}
        Database_Name ${AZURE_KUSTO_DATABASE}
        Table_Name MyTable
        Include_Tag_Key On
        Include_Time_Key On