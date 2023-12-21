import os
from google.cloud import dataform_v1beta1

from flask import Flask, request


app = Flask(__name__)

from google.cloud import dataform_v1beta1

def sample_create_compilation_result(project, location, dataform_repo_name, dataform_release_name):
    client = dataform_v1beta1.DataformClient()
    compilation_result = dataform_v1beta1.CompilationResult()
    compilation_result.release_config = f"projects/{project}/locations/{location}/repositories/{dataform_repo_name}/releaseConfigs/{dataform_release_name}"

    request = dataform_v1beta1.CreateCompilationResultRequest(
        parent=f"projects/{project}/locations/{location}/repositories/{dataform_repo_name}",
        compilation_result=compilation_result,
    )
    compilation_result = client.create_compilation_result(request=request)
    print(compilation_result)
    return compilation_result.name
    
    
def sample_create_workflow_invocation(compilation_result_name, project, location, dataform_repo_name):
    client = dataform_v1beta1.DataformClient()
    workflow_invocation = dataform_v1beta1.WorkflowInvocation()
    workflow_invocation.compilation_result = compilation_result_name

    request = dataform_v1beta1.CreateWorkflowInvocationRequest(
        parent=f"projects/{project}/locations/{location}/repositories/{dataform_repo_name}",
        workflow_invocation=workflow_invocation,
    )
    response = client.create_workflow_invocation(request=request)
    print(response)
    return response

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
    dataform_repo_name = os.environ.get('DATAFORM_REPO_NAME')
    dataform_release_name = os.environ.get('DATAFORM_RELEASE_NAME')

    print(f'env vars: project={project}, location={location}, dataform_repo_name={dataform_repo_name}, dataform_release_name={dataform_release_name}')

    try:
        compilation_result_name = sample_create_compilation_result(project, location, dataform_repo_name, dataform_release_name)
        sample_create_workflow_invocation(compilation_result_name, project, location, dataform_repo_name)
    except Exception as e:
        print(f"Error during processing: {e}")
        return (f"Completed Request", 204)
    return (f"Successful Request", 204)