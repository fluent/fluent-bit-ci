apiVersion: apps/v1
kind: Deployment
metadata:
  name: msal-proxy
  labels:
    app: msal-proxy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: msal-proxy
  template:
    metadata:
      labels:
        app: msal-proxy
    spec:
      containers:
      - name: msal-proxy
        image: papigers/msal-proxy
        ports:
        - containerPort: 8000
        env:
        - name: REMOTE
          value: "${AZURE_KUSTO_ENDPOINT}"
        - name: APP_ID
          value: "${AZURE_KUSTO_CLIENT_ID}"
        - name: APP_SECRET
          value: "${AZURE_KUSTO_CLIENT_SECRET}"
        - name: APP_TENANT_ID
          value: "${AZURE_KUSTO_TENANT_ID}"
        - name: SCOPE
          value: "https://help.kusto.windows.net/.default"