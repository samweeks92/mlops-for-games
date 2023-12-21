package main

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"fmt"
    "os"
	"io"
	"net/http"
	"time"

	"cloud.google.com/go/storage"
	"google.golang.org/api/iterator"
)

var userLookup map[string][]string

func downloadLatestObject(ctx context.Context, bucket *storage.BucketHandle) (*storage.Reader, error) {
	var latestObj *storage.ObjectAttrs
	latestTime := time.Time{}

	it := bucket.Objects(ctx, nil)
	for {
		objAttrs, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, err
		}

		if objAttrs.Updated.After(latestTime) {
			latestTime = objAttrs.Updated
			latestObj = objAttrs
		}
	}

	if latestObj == nil {
		return nil, fmt.Errorf("no object found in bucket")
	}

	return bucket.Object(latestObj.Name).NewReader(ctx)
}

func readCSVAndBuildLookup(reader *storage.Reader) (map[string][]string, error) {
	r := csv.NewReader(reader)
	r.Comma = ';' // Set the semicolon as the delimiter

	// Read and skip the header row
	_, err := r.Read()
	if err != nil {
		return nil, err
	}

	userLookup := make(map[string][]string)
	for {
		record, err := r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}

		// Use the first column (user_pseudo_id) as the key
		userLookup[record[0]] = record
	}

	return userLookup, nil
}

// getBucketMetadata gets the bucket metadata.
func getUserLookup(ctx context.Context, bucketName string) (map[string][]string, error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		return nil, fmt.Errorf("storage.NewClient: %w", err)
	}
	defer client.Close()

	ctx, cancel := context.WithTimeout(ctx, time.Second*10)
	defer cancel()
	bucket := client.Bucket(bucketName)

	// Download the latest object and build the lookup map
	reader, err := downloadLatestObject(ctx, bucket)
	if err != nil {
		return nil, err
	}
	defer reader.Close()

	userLookup, err := readCSVAndBuildLookup(reader)
	if err != nil {
		panic(err)
	}
	// fmt.Println("userLookup contents:", userLookup)

	return userLookup, nil
}

func getUserInfoHandler(w http.ResponseWriter, r *http.Request) {

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	var requestPayload map[string]string

	err = json.Unmarshal(body, &requestPayload)
	if err != nil {
		http.Error(w, "Error parsing JSON body", http.StatusBadRequest)
		return
	}

	userPseudoID, ok := requestPayload["user_pseudo_id"]
	if !ok {
		http.Error(w, "Missing required field 'user_pseudo_id' in request body", http.StatusBadRequest)
		return
	}

	// Use the userLookup map to find information for the given user_pseudo_id
	userInfo, found := userLookup[userPseudoID]
	if !found {
		http.NotFound(w, r)
		return
	}

	// Create a map representing the JSON structure
	userJSONMap := map[string]interface{}{
		"user_pseudo_id":      userInfo[0],
		"churned":             userInfo[1],
		"predicted_churned":   userInfo[2],
		"probability_churned": userInfo[3],
	}

	// Convert user information map to JSON
	userJSON, err := json.Marshal(userJSONMap)
	if err != nil {
		http.Error(w, "Error converting to JSON", http.StatusInternalServerError)
		return
	}

	// Set Content-Type header to indicate JSON response
	w.Header().Set("Content-Type", "application/json")

	// Respond with the JSON-encoded user information
	w.Write(userJSON)
}

func startHTTPServer() {
	http.HandleFunc("/user", getUserInfoHandler)
	http.ListenAndServe(":8080", nil)
}

func main() {
	// Replace "your-bucket-name" with the actual name of your bucket
	bucketName := os.Getenv("BUCKET_NAME")

	var err error
	userLookup, err = getUserLookup(context.Background(), bucketName)
	if err != nil {
		fmt.Printf("Error getting bucket metadata: %v\n", err)
		return
	}

	// You can use 'attrs' to access the metadata information if needed
	fmt.Printf("Bucket metadata retrieved successfully.")
	fmt.Printf("%T\n", userLookup)

	// Start the HTTP server in a goroutine
	go startHTTPServer()

	// Keep the program running
	select {}

}