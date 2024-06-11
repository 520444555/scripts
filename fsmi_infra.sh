gcloud auth activate-service-account  terraform-jenkins-usr@hsbc-11597902-fsmiasp-dev.iam.gserviceaccount.com --key-file="C:\Users\43721934\Downloads\hsbc-11597902-fsmiasp-dev-703c148545e9.json"
 
gcloud config set project hsbc-11597902-fsmiasp-dev
gcloud config set proxy/address googleapis-dev.gcp.cloud.uk.hsbc
 
gcloud config set proxy/address googleapis-prod.gcp.cloud.uk.hsbc
 
 
gcloud compute networks subnets list
 
gcloud compute addresses list
 
gcloud compute addresses create fsmi-etl-vm1-address --region asia-east2 --subnet=projects/hsbc-6320774-vpchost-asia-dev/regions/asia-east2/subnetworks/cinternal-vpc1-asia-east2
 
gcloud compute addresses create fsmi-squid-proxy-primary-address --region asia-east2 --subnet=projects/hsbc-6320774-vpchost-asia-dev/regions/asia-east2/subnetworks/cinternal-vpc1-asia-east2
 
gcloud compute addresses create fsmi-squid-proxy-secondary-default-address --region asia-east2 --subnet=dataproc-asia-east2
gcloud compute addresses create fsmi-jenkins-slave-address --region asia-east2 --subnet=projects/hsbc-6320774-vpchost-asia-dev/regions/asia-east2/subnetworks/cinternal-vpc1-asia-east2
 
gcloud compute addresses list
 
 
gcloud compute addresses delete fsmi-squid-proxy-primary-address --region asia-east2
 
 
gcloud compute instances delete fsmiasp-prod-etlvm
 
 
 
 
gcloud compute disks snapshot fsmiasp-prod-etlvm --project=hsbc-11597902-fsmiasp-prod --snapshot-names=fsmiasp-prod-etlvm-snapshot-1 --zone=asia-east2-b --storage-location=asia-east2
