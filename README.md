# Windows Machine File Copy Task (WinRM)

## Overview

The task is used to copy application files and other artifacts that are required to install the application on Windows Machines like PowerShell scripts, PowerShell-DSC modules etc. The task provides the ability to copy files to Windows Machines. The tasks uses WinRM for the data transfer.

> This task defers from the original task that ships with VSTS/TFS by the fact that this implementation uses WinRM for the file transfer instead of robocopy on which the original task is based on.
In certain situations, due to the network restrictions, mounting the drive and using the necessary protocols is not possible. Thus, for such scenarios, where WinRM is enabled, this task will solve the issue.

## Requirements

The only requirement is PowerShell V5 installed both on the build server and on the machine on which you are trying to copy the files to.

### The different parameters of the task are explained below

* **Source**: The source of the files. As described above using pre-defined system variables like $(Build.Repository.LocalPath) make it easy to specify the location of the build on the Build Automation Agent machine. The variables resolve to the working folder on the agent machine, when the task is run on it. Wild cards like **\\*.zip are not supported. Probably you are going to copy something from your artifacts folder that was generated in previous steps of your build/release, at example '$(System.ArtifactsDirectory)\\Something'.
* **Machines**: Specify comma separated list of machine FQDNs/ip addresses along with port(optional). For example dbserver.fabrikam.com, dbserver_int.fabrikam.com:5988,192.168.34:5933.
* **Admin Login**: Domain/Local administrator of the target host. Format: &lt;Domain or hostname&gt;\\&lt; Admin User&gt;.  
* **Password**:  Password for the admin login. It can accept variable defined in Build/Release definitions as '$(passwordVariable)'. You may mark variable type as 'secret' to secure it.
* **Destination Folder**: The folder in the Windows machines where the files will be copied to. An example of the destination folder is c:\\FabrikamFibre\\Web.
* **Use SSL**: In case you are using secure WinRM, HTTPS for transport, this is the setting you will need to flag.
* **Using Test Certificate** Available only if **Use SSL** is selected. If this option is selected, client skips the validation that the server certificate is signed by a trusted certificate authority (CA) when connecting over Hypertext Transfer Protocol over Secure Socket Layer (HTTPS).
* **Clean Target**: Checking this option will clean the destination folder prior to copying the files to it.
* **Copy Files in Parallel**: Checking this option will copy files to all the target machines in parallel, which can speed up the copying process.

## Task version history

* 2.0.7 - A bug has been addressed that will not ignore certs in case of parallel copy ([#11](https://github.com/mmajcica/win-rm-file-copy/issues/11))
* 2.0.7 - Solved the issue where task can't resolve reverse DNS for IP addresses ([#4](https://github.com/mmajcica/win-rm-file-copy/issues/4))
* 2.0.6 - "minimumAgentVersion" set to "1.95.0" in order to ensure the compatibility with TFS 2015 Update 2 ([#5](https://github.com/mmajcica/win-rm-file-copy/issues/5))
* 2.0.5 - Solved the issues introduced with v2.0.2 where reverse lookup data in DNS is not present
* 2.0.2 - Resolve CNAME before creating a WinRM session ([#2](https://github.com/mmajcica/win-rm-file-copy/issues/2))
* 2.0.1 - Implements the Skip CA Check for HTTPS with a self signed certificate ([#1](https://github.com/mmajcica/win-rm-file-copy/issues/1))

[![Build Status](https://dev.azure.com/mummy/Azure%20DevOps%20Extensions/_apis/build/status/mmajcica.win-rm-file-copy?branchName=master)](https://dev.azure.com/mummy/Azure%20DevOps%20Extensions/_build/latest?definitionId=43&branchName=master)

## Contributing

Feel free to notify any issue in the issues section of this GitHub repository. In order to build this task, you will need Node.js and gulp installed. Once cloned the repository, just run 'npm install' then 'gulp package' and in the newly created folder called _packages you will find a new version of the extension.
