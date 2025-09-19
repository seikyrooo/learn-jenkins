package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/hello", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "Hello from Go API in Kubernetes! Deploy pake Control")
	})

	log.Println("Starting server on :8050")
	log.Fatal(http.ListenAndServe(":8050", nil))
}