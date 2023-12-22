# Build and deploy the streaming-beam Dataflow service

# This Image is built from the source code in /services/dataflow.
# This pipeline will pull event messages published onto a PubSub Topic (default topic name is game_telemetry_streaming_topic), then run some transformation steps and write the events to the BigQuery table (default table is: unified_data.game_telemetry)
# The Cloud Build Trigger that was created by Terraform in the previous step will build the Image for your events streaming pipeline that will run on Dataflow.

gcloud builds triggers run streaming-beam --region=$GCP_REGION --project=$GCP_PROJECT_ID --branch=main



# Build and deploy the event-ingest service

# The Event Ingest service will be deployed to GKE and is responsible for receiving and routing all game telemetry data from Game clients through to the MLOps pipeline.
# The Event Ingest service is also resposible for sending spend prediction requests to the spend ml serving image and returning prediction results back to the game clients.
# The Event Ingest service is also resposible for sending churn lookup requests to the churn lookup service and returning user churn results back to the game clients.

gcloud builds triggers run event-ingest --region=$GCP_REGION --project=$GCP_PROJECT_ID --branch=main



# Build and deploy the tcp-load service

# This creates a service in gke called tcp-load which is used to generate an artifical game data load at the event-ingest service.

gcloud builds triggers run tcp-load --region=$GCP_REGION --project=$GCP_PROJECT_ID --branch=main



# Build and deploy the cloudrun-run-pipeline service 

# This service is triggered by a PubSub notification in the event of the  BigQuery update alert being fired. 
# It is used to create the Vertex AI Pipeline Job which outputs a trained spend prediction model to GCS

gcloud builds triggers run ml-training-spend-cloudrun-run-pipeline --region=$GCP_REGION --project=$GCP_PROJECT_ID --branch=main



# Build and deploy the cloudrun-build-serving-image service 

# This is a Cloud Run service that sits between the Vertex AI Pipeline and
# the Cloud Build job to containerise the spend prediction model.
# This Cloud Build servics is essentially a filter, and allows us to only trigger the Cloud Build job when the `saved_model.pb` file is updated.
# Otherwise, Cloud Build would be triggered for every update of any Object in the `gs://<PROJECT_ID>-mlops-spend` bucket.

gcloud builds triggers run ml-training-spend-cloudrun-build-serving-image --region=$GCP_REGION --project=$GCP_PROJECT_ID --branch=main
# Now the pipeline can be ran, and the outputted model files will automatically be built into a serving image and deployed to GKE.



# Build and deploy the cloudrun-run-dataform service 

# This service is triggered by a PubSub notification in the event of the  BigQuery update alert being fired. 
# It is used to invoke the Dataform workflow which outputs a .csv of batch prediction results for churn likelyhood to GCS.

gcloud builds triggers run ml-training-churn-cloudrun-run-dataform --region=$GCP_REGION --project=$GCP_PROJECT_ID --branch=main