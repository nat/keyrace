package main

import (
	"fmt"
	"net/http"
	"strconv"
)

var scoreboards map[string]map[string]int

func count(w http.ResponseWriter, req *http.Request) {
	fmt.Println(req.URL.String())

	count, err := strconv.Atoi(req.URL.Query()["count"][0])
	if err != nil {
		fmt.Fprintf(w, "Errror parsing count")
		return
	}

	keys, ok := req.URL.Query()["name"]
	if !ok || len(keys[0]) < 1 {
		return
	}
	name := keys[0]

	keys, ok = req.URL.Query()["team"]
	if !ok || len(keys[0]) < 1 {
		return
	}
	team := keys[0]

	if _, ok := scoreboards[team]; !ok {
		scoreboards[team] = make(map[string]int)
	}

	scoreboard, ok := scoreboards[team]
	if ok {
		fmt.Fprintf(w, "updated count for %s from %d to %d\n", name, scoreboard[name], count)
		scoreboard[name] = count
	}
}

func index(w http.ResponseWriter, req *http.Request) {
	fmt.Println(req.URL.String())

	team := req.URL.Query()["team"][0]
	scoreboard := scoreboards[team]

	for key, value := range scoreboard {
		fmt.Fprintf(w, "%-20s%d\n", key, value)
	}
}

func main() {
	scoreboards = make(map[string]map[string]int)

	http.HandleFunc("/count", count)
	http.HandleFunc("/", index)

	http.ListenAndServe(":80", nil)
}
