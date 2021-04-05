# kubemark-tool
tools that might help with kubemark testing


## Client machine setup
The was my client profile, FYI:
* Ubuntu 20.04 LTS
* n2-standard-8 (8 cores, 32 GB ram, 800 GB disk)
* gcloud Full API access (as it needs to access Google Cloud API a lot!)
* apt install zip pyton-is-python3
* gcloud init


## Source code notes
Usually the community ETCD is preferrable, whose patch is right now in out-of-tree commit 992ec184 (ETCD 3.4.3)


## How to use it
It applies to Arktos project purposedly.

1. ensure arktos-tool/ is at ~/ (may need to run git clone https://sonyafenge@github.com/sonyafenge/arktos-tool.git)
1. create symbolic link to the shell script at <ARKTOS-REPO-ROOT>
1. assuming make quick-release has been done;
1. source ./kubemark-setup.sh hw-density-1x100 100 2 3 (2tpx3rp, typically takes 80 minutes to finish the specific one)

Enjoy!
