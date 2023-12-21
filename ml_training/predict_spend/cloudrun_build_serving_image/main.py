import os
from google.cloud.devtools import cloudbuild_v1

from flask import Flask, request


app = Flask(__name__)

def run_trigger(model_id, timestamp):
    # Create a client
    client = cloudbuild_v1.CloudBuildClient()

    # Initialize request argument(s)
    repo_source = cloudbuild_v1.RepoSource()
    repo_source.branch_name = "main"
    repo_source.repo_name = os.environ.get('REPO_NAME')
    repo_source.project_id = os.environ.get('PROJECT')
    repo_source.substitutions = {
        "_MODEL_TIMESTAMP": timestamp,
        "_MODEL_ID": model_id
    }

    
    request = cloudbuild_v1.RunBuildTriggerRequest(
        name = f"projects/{os.environ.get('PROJECT')}/locations/{os.environ.get('LOCATION')}/triggers/{os.environ.get('TRIGGER_NAME')}",
        project_id=os.environ.get('PROJECT'),
        trigger_id=os.environ.get('TRIGGER_NAME'),
        source = repo_source
    )

    # Make the request
    print (f"Sending request to trigger Cloud Build using env vars _MODEL_ID: {model_id} _MODEL_TIMESTAMP {timestamp}")
    print(f"env vars: project={os.environ.get('PROJECT')}, location={os.environ.get('LOCATION')}, trigger_name={os.environ.get('TRIGGER_NAME')}, repo_name={os.environ.get('REPO_NAME')}")
    print(f"request.name {request.name}")
    print(f"request.project_id {request.project_id}")
    print(f"request.trigger_id {request.trigger_id}")
    print(f"request.source {request.source}")
    operation = client.run_build_trigger(request=request)
    print("Waiting for operation to complete...")

    response = operation.result()
    return response

@app.route("/", methods=["POST"])
def index():
    """Receive and parse Pub/Sub messages."""
    msg = ""
    envelope = request.get_json()
    if not envelope:
        msg = "no Pub/Sub message received"
        return (f"Completed Request: {msg}", 204)

    if not isinstance(envelope, dict) or "message" not in envelope:
        msg = "invalid Pub/Sub message format"
        return (f"Completed Request: {msg}", 204)

    
    print(f"env vars: project={os.environ.get('PROJECT')}, location={os.environ.get('LOCATION')}, trigger_name={os.environ.get('TRIGGER_NAME')}, repo_name={os.environ.get('REPO_NAME')}")
        
    pubsub_message_attributes = envelope["message"]["attributes"]

    if isinstance(pubsub_message_attributes, dict) and "bucketId" in pubsub_message_attributes and "objectId" in pubsub_message_attributes:
        bucketId = pubsub_message_attributes['bucketId']
        objectId = pubsub_message_attributes['objectId']
        msg = f"bucket: {bucketId}, object: {objectId}"
        print(msg)
        if "saved_model.pb" in objectId:
            model_id = objectId.split("/")[0]
            model_timestamp = objectId.split("/")[2]
            print (f"For saved_model.pb object: model_id is: {model_id}. model_timestamp is: {model_timestamp}")
            try:
                run_trigger(model_id=model_id,timestamp=model_timestamp)
            except Exception as e:
                print(f"Error during processing: {e}")
                return (f"Completed Request: {msg}", 204)
            return (f"Successful Request: {msg}", 204)
        else:
            print ("object in the ml-ops-spend bucket, but is not saved_model.pb object so ignoring this object to avoid duplicate triggers of cloud build")
            return (f"Successful Request: {msg}", 204)
    
    else:
        print("bucketId and objectId are not both found in the PubSub message attributes!")
        return (f"Successful Request: {msg}", 204)