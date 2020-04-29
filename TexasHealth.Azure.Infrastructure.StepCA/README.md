# Azure Step CA Docker Image

This project builds a Docker image of Smallstep's Step CA software. This is a certificate authority server that supports the ACME protocol.

The image is setup to take environmental variables refering to a Key Vault of the CA. It runs a init.sh script which auto generates all of the configuration and downloads the CA from KeyVault. It requires a file system mount to store the state data.
