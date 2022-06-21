
```
gcloud auth application-default login
packer build packer.json
```

To modify test runs there are three options:
1. Provide a `.env` file with any custom variables.
2. Provide a `docker-compose.yml` file with a full stack config.
3. Provide a `run.sh` file to invoke instead.