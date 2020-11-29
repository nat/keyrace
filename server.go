package main

import (
	"fmt"
	"net/http"
	"strconv"
)

var scoreboard map[string]int

func count(w http.ResponseWriter, req *http.Request) {
	count, err := strconv.Atoi(req.URL.Query()["count"][0])
	if err != nil {
		fmt.Fprintf(w, "Errror parsing count")
		return
	}

	name := req.URL.Query()["name"][0]
	scoreboard[name] = count
}

func index(w http.ResponseWriter, req *http.Request) {
	for key, value := range scoreboard {
		fmt.Fprintf(w, "%-20s%d\n", key, value)
	}
}

func main() {
	scoreboard = make(map[string]int)

	http.HandleFunc("/count", count)
	http.HandleFunc("/", index)

	http.ListenAndServe(":80", nil)
}
