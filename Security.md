# Kubernetes security with Kubescape
## Introduction
Kubescape is ...  
In this repo, we are going to use Kubescape in order to implement best practices in our K8s cluster.  
In this repo, we focus on the High-stakes workloads defined as those which Kubescape estimates would have the highest impact if they were to be exploited, and which represent the application worlkload in our case (the web application, the database application and the streamer application).
## Kubescape installation
## Running a scan
```bash
# Define a name for your scan
export SCAN_NAME=my_scan_name
make scan
```
## Security Aspects
### Using secrets
This security best practice solve a very important issue which is "Application credentials in configuration files".  
Putting the credentials of an application in configuration files is a rooky mistake because it exposes the credentials of the application to anyone who has a read access of the configuration file, for example if the configuration code is stored in a public GitHub repo then the whole world has access to the credentials of your application.  
Hence a common practice is to use Kubernetes secrets to store the sensitive information like password and access tokens.  
In the examples used in this project we store the secret credentials in files in a folder called secrets, in a real world example such a folder should be only accessible by specific users in case some initial configuration should be hardcoded, otherwise the credentials should be stored programatically (through a UI for example) and should not be directly exposed anywhere.  
#### Scanning
To scan for this security issue we should run
```bash
kubescape scan control C-0012 -v
```
#### Adding secrets
We use linux env variables to store the secrets of the database and web applications, these env variables are stored in the `/secrets` folder.  
Once we have the env variables set, we create the K8s secrets
```bash
make secrets
```
#### Scanning
After changing the deployments configuration with adding the K8s secrets, we rerun our applications and run a new scan to see that the "Application credentials in configuration files" issue has been indeed solved.  
The corresponding scans have a scan name: `secret_scan.html`, `secret_scan.pdf` and `secret_scan.pretty-printer`
```bash
export SCAN_NAME="secret_scan"
make scan
```
### Adding Container limits
This is not a security threat per se, but in order to ensure that a pod does not overuse the resources of the nodes.  
We can scan for this issue using:
```bash
kubescape scan control C-0270 -v # CPU limits
kubescape scan control C-0271 -v # Memory limits
```
### Adding network policies
### Solving Workload-related issues
### Access control