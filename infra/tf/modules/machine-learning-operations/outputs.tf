
// Output the mlops-spend bucket name
output "mlops-spend-bucket-name" {
  value = google_storage_bucket.mlops-spend-bucket.name
}

// Output the mlops-churn bucket name
output "mlops-churn-bucket-name" {
  value = google_storage_bucket.mlops-churn-bucket.name
}