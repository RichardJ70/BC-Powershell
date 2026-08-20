In the Cloud folder all scripts using the admin center API are stored
In the On-Prem folder the same for on premise multi tenant installations
In the General folder some usefull general scripts will be stored

The Cloud folder contains several scripts with a number in the file name suggesting the order in which to execute them.
The files starting with 1. and 2. are used in de files starting with 3, 4, 5 and 6. The other files are for stand alone usage.

Use the 1. files for authentication. Either use BcContainerHelper with a device login or use standaard Microsoft S2S.
Use the 2. files to handle a single environment of multi environments in the same Microsoft tenant.
Use the 3. files to handle installation of global apps, app updates or uninstallation of global apps.
Use the 4. file to handle scheduling major or minor releases
Use the 5. files to set environment settings
Use the 6. files to handle enviroment actions

PTE - Pipelines is work in progress. 
AL-GO works for standard BC implementations but not with a BC solution using a different application family, when the partner has not published a public package for their solution. 
If anyone knows a way to handle this with Git CI/CD please let me know. 
For now investigation is done to download all installed apps so merging can take place locally, using the script to download all the global (appsource) apps installed on the environment.

# update #
Since Admin center API version V2.29 it is possible to publish and install PTE extensions
However, for now, 08/20/26, authentication with BCContainerHelper crashes. This is under investigation with Microsoft.
