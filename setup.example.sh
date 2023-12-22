# Check if gcloud SDK is installed
if ! command -v gcloud &>/dev/null; then
  echo "Please install the gcloud SDK."
  echo "https://cloud.google.com/sdk/docs/install-sdk"
  exit 1
fi

# Check if user is authenticated
if ! gcloud auth list &>/dev/null; then
  echo "Please authenticate with the gcloud SDK."
  gcloud auth application-default login
fi

# 1. Get GCP Project ID and Project Number from gcloud
export GCP_PROJECT_ID=YOUR_PROJECT_ID
export GCP_REGION=YOUR_GCP_REGION
export CLOUD_SOURCE_REPO_NAME=YOUR_CLOUD_SOURCE_REPO_NAME

# 2. Set Project ID
gcloud config set project $GCP_PROJECT_ID

export GCP_PROJECT_NUMBER=$(gcloud projects describe "$GCP_PROJECT_ID" --format="value(projectNumber)" 2>/dev/null)
export TF_STATE_BUCKET_NAME=$GCP_PROJECT_ID-tf-state

# 3. Enable Google Cloud APIs required for deployments
gcloud services enable \
iam.googleapis.com \
cloudbuild.googleapis.com \
storage.googleapis.com \
cloudresourcemanager.googleapis.com \
compute.googleapis.com \
servicecontrol.googleapis.com \
container.googleapis.com \
artifactregistry.googleapis.com \
bigquery.googleapis.com \
bigquerydatatransfer.googleapis.com \
aiplatform.googleapis.com

# 4. Create GCS Bucket for the Terraform Init state

gsutil mb gs://$TF_STATE_BUCKET_NAME
gsutil versioning set on gs://$TF_STATE_BUCKET_NAME

# 5. Grant Cloud Build additional permissions to permission to manage the Project

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/serviceusage.serviceUsageAdmin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/resourcemanager.projectIamAdmin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/iam.roleAdmin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/iam.serviceAccountAdmin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/iam.serviceAccountCreator
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/viewer
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/cloudbuild.builds.editor
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/compute.admin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/compute.networkAdmin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/compute.loadBalancerAdmin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/servicenetworking.serviceAgent
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/container.clusterAdmin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/container.admin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/vpcaccess.admin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/storage.admin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/storage.objectAdmin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/artifactregistry.admin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/bigquery.dataEditor
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/dataflow.admin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/dataflow.serviceAgent
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/aiplatform.user
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/monitoring.editor
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/run.admin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/dataform.admin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/secretmanager.admin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member=serviceAccount:$GCP_PROJECT_NUMBER@cloudbuild.gserviceaccount.com  --condition=None --role=roles/artifactregistry.admin

# 6.  Apply the Build Trigger for the infrastructure

gcloud builds triggers create cloud-source-repositories --name=terraform-apply --region=$GCP_REGION --repo=$CLOUD_SOURCE_REPO_NAME --branch-pattern=main --build-config=infra/cloudbuild/cloudbuild-tf-apply.yaml --included-files=infra/tf/** --substitutions _TF_STATE_BUCKET_NAME_=$TF_STATE_BUCKET_NAME,_PROJECT_ID_=$GCP_PROJECT_ID,_PROJECT_NUMBER_=$GCP_PROJECT_NUMBER,_CLOUD_SOURCE_REPO_NAME_=$CLOUD_SOURCE_REPO_NAME,_GCP_REGION=$GCP_REGION

gcloud builds triggers create manual --name=terraform-plan --region=$GCP_REGION --repo-type=CLOUD_SOURCE_REPOSITORIES --repo=https://source.developers.google.com/p/$GCP_PROJECT_ID/r/$CLOUD_SOURCE_REPO_NAME --branch=main --build-config=infra/cloudbuild/cloudbuild-tf-plan.yaml --substitutions _TF_STATE_BUCKET_NAME_=$TF_STATE_BUCKET_NAME,_PROJECT_ID_=$GCP_PROJECT_ID,_PROJECT_NUMBER_=$GCP_PROJECT_NUMBER,_CLOUD_SOURCE_REPO_NAME_=$CLOUD_SOURCE_REPO_NAME,_GCP_REGION=$GCP_REGION
gcloud builds triggers create manual --name=terraform-destroy --region=$GCP_REGION --repo-type=CLOUD_SOURCE_REPOSITORIES --repo=https://source.developers.google.com/p/$GCP_PROJECT_ID/r/$CLOUD_SOURCE_REPO_NAME --branch=main --build-config=infra/cloudbuild/cloudbuild-tf-destroy.yaml --substitutions _TF_STATE_BUCKET_NAME_=$TF_STATE_BUCKET_NAME,_PROJECT_ID_=$GCP_PROJECT_ID,_PROJECT_NUMBER_=$GCP_PROJECT_NUMBER,_CLOUD_SOURCE_REPO_NAME_=$CLOUD_SOURCE_REPO_NAME,_GCP_REGION=$GCP_REGION

# 7. Run the Build Trigger for the infrastructure

gcloud builds triggers run terraform-apply --region=$GCP_REGION --project=$GCP_PROJECT_ID --branch=main

echo ""
echo "*************************************************"
echo ""
echo "Setup Complete!"
echo "Infrastructure is rolling out. check Cloud Build"
echo ""
echo "*************************************************"
echo ""