import os
from google.cloud import aiplatform

from flask import Flask, request


app = Flask(__name__)

def run_pipeline(project_id, loc, pipeline_root, service_account):
    
    # Create a PipelineJob using the compiled pipeline from pipeline_spec_uri
    aiplatform.init(
        project=project_id,
        location=loc,
    )
    
    # Prepare the pipeline job
    job = aiplatform.PipelineJob(
        display_name="spend-pipeline-bigquery-update",
        template_path=f"{pipeline_root}/spend_pipeline.yaml",
        pipeline_root=pipeline_root,
        parameter_values={
            'project_id': project_id
        }
    )

    #Submit the job
    job.submit(
        service_account = service_account
    )

@app.route("/", methods=["POST"])
def index():
    """Receive and parse Pub/Sub messages."""
    envelope = request.get_json()
    if not envelope:
        msg = "no Pub/Sub message received"
        return (f"Completed Request: {msg}", 204)

    # Retrieve values from environment variables
    project = os.environ.get('PROJECT')
    location = os.environ.get('LOCATION')
    pipeline_root = os.environ.get('PIPELINE_ROOT')
    service_account = os.environ.get('SERVICE_ACCOUNT')

    print(f'env vars: project={project}, location={location}, pipeline_root={pipeline_root}, serviceaccount={service_account}')

    try:
        run_pipeline(project_id=project, loc=location, pipeline_root=pipeline_root, service_account=service_account)
    except Exception as e:
        print(f"Error during processing: {e}")
        return (f"Completed Request", 204)
    return (f"Successful Request", 204)