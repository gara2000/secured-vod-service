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
### Adding network policies
### Solving Workload-related issues
### Access control