# ################################################################################################################
# #
# #   Google Cloud Dataflow
# #
# #   References:
# #   https://cloud.google.com/dataflow/docs/
# #
# #
# ################################################################################################################


# from __future__ import absolute_import
# import os
# import logging
# import argparse
# import json
# import apache_beam as beam
# from apache_beam import window
# from apache_beam.options.pipeline_options import PipelineOptions
# from apache_beam.options.pipeline_options import StandardOptions
# from apache_beam.options.pipeline_options import SetupOptions

# ################################################################################################################
# #
# #   BQ Schema
# #
# ################################################################################################################

# # Read the JSON content from the file
# with open('events-streamed-table-schema.json', 'r') as file:
#     shema_fields = json.load(file)
    
# bq_schema = {
#     "fields": shema_fields
# }

# ################################################################################################################
# #
# #   Functions
# #
# ################################################################################################################

# def parse_pubsub(event):
#     return json.loads(event)


# def preprocess_event(event):
#     return event


# def print_event(event):
#     print('{}'.format(event))

# def run(argv=None):
#     """Build and run the pipeline."""
#     parser = argparse.ArgumentParser()
#     parser.add_argument('--gcp_project',          required=True,    default='gaming-demos',       help='GCP Project ID')
#     parser.add_argument('--region',               required=True,    default='us-central1',        help='GCP Region')
#     parser.add_argument('--job_name',             required=True,    default='antidote-ensemble',  help='Dataflow Job Name')
#     parser.add_argument('--gcp_staging_location', required=True,    default='gs://xxxxx/staging', help='Dataflow Staging GCS location')
#     parser.add_argument('--gcp_tmp_location',     required=True,    default='gs://xxxxx/tmp',     help='Dataflow tmp GCS location')
#     parser.add_argument('--batch_size',           required=True,    default=10,                   help='Dataflow Batch Size')
#     parser.add_argument('--pubsub_topic',         required=True,    default='',                   help='Input PubSub Topic: projects/<project_id>/topics/<topic_name>')#parser.add_argument('--bq_dataset_name',      required=True,   default='',                   help='Output BigQuery Dataset')
#     parser.add_argument('--bq_dataset_name',      required=True,    default='',                   help='BigQuery Dataset, used as data sink')
#     parser.add_argument('--bq_table_name',        required=True,    default='',                   help='BigQuery Table, used as data sink')
#     parser.add_argument('--runner',               required=True,    default='DirectRunner',       help='Dataflow Runner - DataflowRunner or DirectRunner (local)')

#     known_args, pipeline_args = parser.parse_known_args(argv)
    
#     pipeline_args.extend([
#           '--runner={}'.format(known_args.runner),                          # DataflowRunner or DirectRunner (local)
#           '--project={}'.format(known_args.gcp_project),
#           '--staging_location={}'.format(known_args.gcp_staging_location),  # Google Cloud Storage gs:// path
#           '--temp_location={}'.format(known_args.gcp_tmp_location),         # Google Cloud Storage gs:// path
#           '--job_name=' + str(known_args.job_name),
#       ])
    
#     pipeline_options = PipelineOptions(pipeline_args)
#     pipeline_options.view_as(SetupOptions).save_main_session = True
#     pipeline_options.view_as(StandardOptions).streaming = True
    
#     print('[ INFO ] GCP PROJECT ID: {}'.format(known_args.gcp_project))
#     print('[ INFO ] BQ DATASET NAME: {}'.format(known_args.bq_dataset_name))
#     print('[ INFO ] BQ TABLE NAME: {}'.format(known_args.bq_table_name))

#     os.environ['GOOGLE_CLOUD_PROJECT'] = known_args.gcp_project
#     ###################################################################
#     #   DataFlow Pipeline
#     ###################################################################

#     with beam.Pipeline(options=pipeline_options) as p:
        
#         # Get PubSub Topic
#         logging.info('Ready to process events from PubSub topic: {}'.format(known_args.pubsub_topic)) 
#         events = ( 
#                  p  | 'raw events' >> beam.io.ReadFromPubSub(known_args.pubsub_topic) 
#         )
        
#         # Parse events
#         parsed_events = (
#             events  | 'parsed events' >> beam.Map(parse_pubsub)
#         )

#         # Print results to console (for testing/debugging)
#         events | 'Raw events received'   >> beam.Map(print_event)
        
#         # Parse events
#         preprocessed_events = (
#             parsed_events  | 'Preprocessed events' >> beam.Map(preprocess_event)
#         )

#         # Event Window Transform
#         event_window = (
#             preprocessed_events | 'Window processing' >> beam.WindowInto(window.SlidingWindows(60, 15)) # Window is 60 seconds in length, and a new window begins every 15 seconds
#         )
        
#         # Print results to console (for testing/debugging)
#         event_window | 'Print window processed events'   >> beam.Map(print_event)

#         # Sink/Persist to BigQuery
#         event_window | 'Write to bq' >> beam.io.gcp.bigquery.WriteToBigQuery(
#                         project=known_args.gcp_project,
#                         dataset=known_args.bq_dataset_name,
#                         table=known_args.bq_table_name,
#                         schema=bq_schema,
#                         batch_size=int(known_args.batch_size)
#                         )


# ################################################################################################################
# #
# #   Main
# #
# ################################################################################################################

# if __name__ == '__main__':
#     logging.basicConfig(level=logging.INFO)
#     run()


