package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"text/tabwriter"
	"time"
)

var scoreboards map[string]*Team

type Team struct {
	// We have a mutex here so we can add and update players safely.
	mu      sync.Mutex
	Players []Player
}

// byScore implements sort.Interface for []player based on
// the score field.
type byScore []Player

type Player struct {
	Name              string
	Score             int
	TimeLastCheckedIn time.Time
}

// Len is part of sort.Interface.
func (s byScore) Len() int {
	return len(s)
}

// Swap is part of sort.Interface.
func (s byScore) Swap(i, j int) {
	s[i], s[j] = s[j], s[i]
}

// Less is part of sort.Interface.
func (s byScore) Less(i, j int) bool {
	return s[i].Score > s[j].Score
}

func count(w http.ResponseWriter, req *http.Request) {
	fmt.Println(req.URL.String(), getIP(req))

	count, err := strconv.Atoi(req.URL.Query()["count"][0])
	if err != nil {
		fmt.Fprintf(w, "Errror parsing count")
		return
	}

	name := getStringParam(req, "name")
	if len(name) == 0 {
		fmt.Fprintln(w, "name must be greater than 0 and less than 50 characters long")
		return
	}

	teamName := getStringParam(req, "team")
	if len(teamName) == 0 {
		fmt.Fprintln(w, "team must be greater than 0 and less than 50 characters long")
		return
	}

	if _, ok := scoreboards[teamName]; !ok {
		scoreboards[teamName] = &Team{}
	}

	scoreboard, ok := scoreboards[teamName]
	if ok {
		// Find the matching player.
		for index, player := range scoreboard.Players {
			if player.Name == name {
				// Update the player and break the loop, returning early.
				fmt.Fprintf(w, "updated count for %s from %d to %d\n", name, player.Score, count)
				player.Score = count
				player.TimeLastCheckedIn = time.Now()

				// Lock the mutex while we update the count.
				scoreboards[teamName].mu.Lock()
				scoreboards[teamName].Players[index] = player
				// Unlock the mutex since we are done updating.
				scoreboards[teamName].mu.Unlock()

				// Return early.
				return
			}
		}

		// If we could not find the matching player, we need to create one.
		fmt.Fprintf(w, "updated count for %s from 0 to %d\n", name, count)
		// Lock the mutex while we update the count.
		scoreboards[teamName].mu.Lock()
		scoreboards[teamName].Players = append(scoreboards[teamName].Players, Player{
			Name:              name,
			Score:             count,
			TimeLastCheckedIn: time.Now(),
		})
		// Unlock the mutex since we are done updating.
		scoreboards[teamName].mu.Unlock()
	}
}

func index(w http.ResponseWriter, req *http.Request) {
	fmt.Println(req.URL.String(), getIP(req))

	teamName := getStringParam(req, "team")
	if len(teamName) == 0 {
		fmt.Fprintln(w, "team must be greater than 0 and less than 50 characters long")
		return
	}

	scoreboard := scoreboards[teamName]

	sort.Sort(byScore(scoreboard.Players))

	// Format left-aligned in tab-separated columns of minimal width 5
	// and at least one blank of padding (so wider column entries do not
	// touch each other).
	t := new(tabwriter.Writer)
	t.Init(w, 5, 0, 1, '\t', 0)
	for _, player := range scoreboard.Players {
		fmt.Fprintf(w, "%s\t%d\t%s\n", player.Name, player.Score, humanTime(player.TimeLastCheckedIn))
	}
	t.Flush()
}

// getStringParam makes sure a string parameter passed to the server fits the constraints.
// If not it will return an empty string.
func getStringParam(req *http.Request, key string) string {
	keys, ok := req.URL.Query()[key]
	if !ok || len(keys[0]) < 1 || len(keys[0]) >= 50 {
		return ""
	}
	return keys[0]
}

// humanTime returns a human-readable approximation of a time.Time
// (eg. "About a minute", "4 hours ago", etc.).
// This is lovingly inspired by:
// https://github.com/docker/go-units/blob/master/duration.go
func humanTime(t time.Time) string {
	d := time.Since(t)
	if seconds := int(d.Seconds()); seconds < 1 {
		return "Less than a second"
	} else if seconds == 1 {
		return "1 second"
	} else if seconds < 60 {
		return fmt.Sprintf("%d seconds", seconds)
	} else if minutes := int(d.Minutes()); minutes == 1 {
		return "About a minute"
	} else if minutes < 60 {
		return fmt.Sprintf("%d minutes", minutes)
	} else if hours := int(d.Hours() + 0.5); hours == 1 {
		return "About an hour"
	} else if hours < 48 {
		return fmt.Sprintf("%d hours", hours)
	} else if hours < 24*7*2 {
		return fmt.Sprintf("%d days", hours/24)
	} else if hours < 24*30*2 {
		return fmt.Sprintf("%d weeks", hours/24/7)
	} else if hours < 24*365*2 {
		return fmt.Sprintf("%d months", hours/24/30)
	}
	return fmt.Sprintf("%d years", int(d.Hours())/24/365)
}

// getIP gets the IP of the incoming request.
func getIP(r *http.Request) string {
	// Get the IP from the X-REAL-IP header
	ip := r.Header.Get("X-REAL-IP")
	netIP := net.ParseIP(ip)
	if netIP != nil {
		return ip
	}

	// Get the IP from X-FORWARDED-FOR header
	ips := r.Header.Get("X-FORWARDED-FOR")
	splitIps := strings.Split(ips, ",")
	for _, ip := range splitIps {
		netIP := net.ParseIP(ip)
		if netIP != nil {
			return ip
		}
	}

	// Get the IP from RemoteAddr
	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return ""
	}
	netIP = net.ParseIP(ip)
	if netIP != nil {
		return ip
	}
	return ""
}

// saveStateToFile writes the JSON contents of the current scoreboard to file.
// The path to the file is passed in to the function.
func saveStateToFile(file string) {
	content, err := json.MarshalIndent(scoreboards, "", " ")
	if err != nil {
		log.Fatalf("creating JSON to save to file failed: %v", err)
	}

	if err := ioutil.WriteFile(file, content, 0644); err != nil {
		log.Fatalf("saving JSON state to file %s failed: %v", file, err)
	}
	fmt.Printf("Saved JSON state to file: %s\n", file)
}

// loadStateFromFile tries to load the state from the file if it exists.
func loadStateFromFile(file string) {
	if _, err := os.Stat(file); os.IsNotExist(err) {
		// The file does not exist, let's return early.
		return
	}

	b, err := ioutil.ReadFile(file)
	if err != nil {
		log.Fatalf("reading from file %s failed: %v", file, err)
	}

	// Try to parse the content as JSON.
	if err := json.Unmarshal(b, &scoreboards); err != nil {
		log.Fatalf("reading content in file %s  as JSON failed: %v", file, err)
	}
}

func main() {
	scoreboards = make(map[string]*Team)
	tmpfile := filepath.Join(os.TempDir(), "keyrace.json")

	// On ^C, or SIGTERM gracefully handle exit.
	signals := make(chan os.Signal)
	signal.Notify(signals, os.Interrupt)
	signal.Notify(signals, syscall.SIGTERM)
	go func() {
		for sig := range signals {
			// Save the file.
			saveStateToFile(tmpfile)
			fmt.Printf("Received %s, exiting.\n", sig.String())
			os.Exit(0)
		}
	}()

	// Try to load from the state file if it exists.
	loadStateFromFile(tmpfile)

	http.HandleFunc("/count", count)
	http.HandleFunc("/", index)

	http.ListenAndServe(":80", nil)
}
