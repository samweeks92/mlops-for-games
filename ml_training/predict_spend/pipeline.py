import kfp
from google.cloud import aiplatform
from google_cloud_pipeline_components.v1.bigquery import BigqueryQueryJobOp
from google_cloud_pipeline_components.v1.dataset import TabularDatasetCreateOp
from google_cloud_pipeline_components.v1.automl.training_job import AutoMLTabularTrainingJobRunOp
from google_cloud_pipeline_components.v1.endpoint import EndpointCreateOp, ModelDeployOp
from google_cloud_pipeline_components.v1.model import ModelExportOp
import google.cloud.aiplatform as aiplatform
from google.cloud import storage
import argparse

parser = argparse.ArgumentParser(description="Run pipeline with specified parameters.")
parser.add_argument("--project_id", type=str, required=True, help="The Google Cloud project ID.")
parser.add_argument("--location", type=str, required=True, help="The Google Cloud region.")
# Add arguments for other variables

args = parser.parse_args()

project_id = args.project_id
location = args.location
training_data_table = "spend_training_data"

pipeline_bucket_name = f"{project_id}-mlops-spend"
pipeline_root_path = f"gs://{pipeline_bucket_name}"
service_account = f"pipeline-sa@{project_id}.iam.gserviceaccount.com"



# Define the workflow of the pipeline.
@kfp.dsl.pipeline(
    name="automl-tabular-training-v2",
    pipeline_root=pipeline_root_path)
def pipeline(project_id: str):
    
    create_view_op = BigqueryQueryJobOp(
    project=project_id,
    location = "US",
    query = f"""
CREATE OR REPLACE VIEW `unified_data.{training_data_table}` AS (
  SELECT
      event_name,
      event_date,
      event_timestamp,
      event_previous_timestamp,
      event_bundle_sequence_id,
      event_server_timestamp_offset,
      user_pseudo_id,
      user_first_touch_timestamp,
      device.operating_system,
      device.language,
      geo.country,
      (SELECT IFNULL(value.int_value, 0) FROM UNNEST(event_params) WHERE key = 'value') as spend_virtual_currency_value
    FROM `unified_data.game_telemetry`
    WHERE event_name = 'spend_virtual_currency'
)"""  
    )
    ds_op = TabularDatasetCreateOp(
        project=project_id,
        location = location,
        display_name="spend-dataset-pipelines",
        bq_source=f'bq://{project_id}.unified_data.{training_data_table}'
    ).after(create_view_op)

    training_job_run_op = AutoMLTabularTrainingJobRunOp(
        dataset=ds_op.outputs["dataset"],
        target_column="spend_virtual_currency_value",
        project=project_id,
        display_name="spend-automl-pipelines-minimize-rmse",
        model_display_name="spend-automl-pipelines-minimize-rmse",
        optimization_prediction_type="regression",
        budget_milli_node_hours=1000,
        optimization_objective="minimize-rmse"
    )

    create_endpoint_op = EndpointCreateOp(
        project=project_id,
        display_name = "spend-automl-pipelines-minimize-rmse-endpoint",
    )

    model_deploy_op = ModelDeployOp(
        model=training_job_run_op.outputs["model"],
        endpoint=create_endpoint_op.outputs['endpoint'],
        dedicated_resources_machine_type = "n1-highmem-4",
        dedicated_resources_accelerator_type = "ACCELERATOR_TYPE_UNSPECIFIED",
        dedicated_resources_min_replica_count=1,
        dedicated_resources_max_replica_count=1,
    )

    model_export_op = ModelExportOp(
        model=training_job_run_op.outputs["model"],
        export_format_id="tf-saved-model",
        artifact_destination=pipeline_root_path
    )
    
    model_export_op.set_caching_options(False)

# Compile the pipeline
kfp.compiler.Compiler().compile(
    pipeline_func=pipeline,
    package_path='spend_pipeline.yaml'
)

# Upload the compiled YAML file to Google Cloud Storage
storage_client = storage.Client(project=project_id)
bucket = storage_client.bucket(pipeline_bucket_name)
blob = bucket.blob('spend_pipeline.yaml')

# Upload the file 
blob.upload_from_filename('spend_pipeline.yaml')

# Initialise Vertex AI
aiplatform.init(
    project=project_id,
    location=location,
)

# Prepare the pipeline job
job = aiplatform.PipelineJob(
    display_name="spend-pipeline",
    template_path="spend_pipeline.yaml",
    pipeline_root=pipeline_root_path,
    parameter_values={
        'project_id': project_id
    }
)

#Submit the job
job.submit(
    service_account = service_account
)