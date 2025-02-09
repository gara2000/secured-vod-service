# Kubernetes security with Kubescape
## Introduction
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
Network policies in a Kubernetes cluster are crucial for controlling traffic flow between pods and external entities, enhancing security by restricting unauthorized access and minimizing the attack surface.  
To scan for this issue use:
```bash
kubescape scan control C-0260 -v
```
### Adding service accounts
Service accounts in Kubernetes are identities assigned to workloads (e.g., Pods) to authenticate with the Kubernetes API, enabling them to perform specific actions based on their associated roles and permissions.  
In addition to defining service accounts, we disable the automatic mounting of service account token. When the service account token is mounted, the workload can potentially use it to make API requests, which could be exploited if the token is compromised.  
To scan for this issue use:
```bash
kubescape scan control C-0034 -v
```
In our case we add 3 separate service accounts which ensures that a compromise in one workload does not impact the others, and also permits fine-tuning the permissions for each workload, avoiding over-permissioning.
### Configuring RBAC
RBAC (Role-Based Access Control) is a security mechanism in Kubernetes that allows us to define roles and assign permissions to service accounts, users, or groups, controlling what actions can be performed on specific resources within the cluster. In our application, RBAC is essential to ensure that each workload (such as the web app, streamer server, and database server) has the least privilege necessary to perform its tasks, reducing the risk of unauthorized access or unintended actions.  
In our case the components we have, do not require any access to the Kubernetes resources inside the cluster hence they should be restricted from making any Kubernetes API calls.
### Disabling container privilege escalation
privilege escalation refers to a process within a container gaining higher permissions than its parent process.  
Our applications do not need any privilege escalation, hence adhering with the principle of least privilege we need to disable this option, by setting allowPrivilegeEscalation: false in the security context of the containers.  
To scan for this issue use:
```bash
kubescape scan control C-0016 -v
```
### Ignoring "Immutable container filesystem" threat
Enforcing an immutable filesystem (readOnlyRootFilesystem: true) is a good security practice as it prevents unauthorized modifications, enhances container security, and reduces attack surfaces. However, in our case, we observed that our application fails when this restriction is applied, as it requires write access to the filesystem for essential operations. Given that functionality is a priority, we create a kubescape exception in order to ignore this issue when scanning, this will ensure that the final complience score won't be affected by this functional issue.