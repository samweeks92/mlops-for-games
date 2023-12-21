// Output the BigQuery Dataset ID
output "dataset_id" {
  value = google_bigquery_dataset.default.dataset_id 
}

// Output the BigQuery Dataset location
output "dataset_location" {
  value = google_bigquery_dataset.default.location
}

// Output the BigQuery Table name
output "table_id" {
  value = google_bigquery_table.default.table_id
}

