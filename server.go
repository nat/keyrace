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

	"golang.org/x/crypto/acme/autocert"
)

var scores ScoreData

type ScoreData struct {
	Players []Player
	// We have a mutex here so we can create and update players safely.
	mu sync.Mutex
}

// byScore implements sort.Interface for []player based on
// the score field.
type byScore []Player

type Player struct {
	Username          string
	Token             string
	Score             int
	TimeLastCheckedIn time.Time
	// We have a mutex here so we can update a player safely.
	mu sync.Mutex
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

	// Get the token from the authorization header.
	ghToken := req.Header.Get("Authorization")
	splitToken := strings.Split(ghToken, "Bearer ")
	// Make sure we actually have a token.
	if len(splitToken) <= 1 {
		fmt.Println("invalid GitHub token")
		return
	}
	ghToken = splitToken[1]

	count, err := strconv.Atoi(req.URL.Query()["count"][0])
	if err != nil {
		fmt.Printf("error parsing count: %v", err)
		return
	}

	// Find the matching player our players.
	for index, player := range scores.Players {
		// Try to find the player by their token.
		// This ensures we don't over-call to the API.
		if player.Token == ghToken {
			// Set their username if it is empty.
			if player.Username == "" {
				player.setGitHubDataFromToken()
			}
			// Update the player and break the loop, returning early.
			fmt.Printf("updated count for %s from %d to %d\n", player.Username, player.Score, count)
			player.Score = count
			player.TimeLastCheckedIn = time.Now()

			// TODO: update the user's organizations based on some time from the time last checked in.
			// Or maybe its a button on the client side.

			// Only update the count if the username for the player is not empty.
			if len(player.Username) > 0 {
				// Lock the mutex while we update the count.
				scores.mu.Lock()
				scores.Players[index] = player
				// Unlock the mutex since we are done updating.
				scores.mu.Unlock()
			}

			// Return early.
			return
		}
	}

	// If we did not find the play based on their token, try to find the player
	// based on their username.
	current_player := Player{
		Username:          "",
		Token:             ghToken,
		Score:             count,
		TimeLastCheckedIn: time.Now(),
	}
	current_player.setGitHubDataFromToken()
	if len(current_player.Username) == 0 {
		fmt.Println("github username cannot be empty")
		return
	}

	for index, player := range scores.Players {
		// Try to find the player based on their username.
		if player.Username == current_player.Username {
			// Update the player and break the loop, returning early.
			fmt.Printf("updated count for %s from %d to %d\n", player.Username, player.Score, count)

			// Only update the count if the username for the player is not empty.
			// Lock the mutex while we update the count.
			scores.mu.Lock()
			scores.Players[index] = current_player
			// Unlock the mutex since we are done updating.
			scores.mu.Unlock()

			// Return early.
			return
		}
	}

	// If we could not find the matching player, we need to create one.
	fmt.Fprintf(w, "updated count for %s from 0 to %d\n", current_player.Username, count)
	// Lock the mutex while we update the count.
	scores.mu.Lock()
	scores.Players = append(scores.Players, current_player)
	// Unlock the mutex since we are done updating.
	scores.mu.Unlock()
}

func index(w http.ResponseWriter, req *http.Request) {
	fmt.Println(req.URL.String(), getIP(req))

	sort.Sort(byScore(scores.Players))

	// Format left-aligned in tab-separated columns of minimal width 5
	// and at least one blank of padding (so wider column entries do not
	// touch each other).
	t := new(tabwriter.Writer)
	t.Init(w, 5, 0, 1, '\t', 0)
	for index, player := range scores.Players {
		// Check if the player has showed up "today".
		// TODO(jess): We should probably sort out whatever timezone the server is running in
		// in the future.
		if isToday(player.TimeLastCheckedIn) {
			fmt.Fprintf(w, "%s\t%d\t%s\n", player.Username, player.Score, humanTime(player.TimeLastCheckedIn))
		} else {
			// Remove the player from the slice.
			scores.Players = removeFromSlice(scores.Players, index)

		}
	}
	t.Flush()
}

func removeFromSlice(slice []Player, index int) []Player {
	return append(slice[:index], slice[index+1:]...)
}

// isToday checks is the time.Time is from "today" where "today" is in terms of
// PT.
func isToday(t time.Time) bool {
	loc, err := time.LoadLocation("America/Los_Angeles")
	if err != nil {
		log.Fatalf("getting time zone location for America/Los_Angeles failed: %v", err)
	}
	// Get today in terms of our location.
	today := time.Now().UTC().In(loc).Day()
	// Get the last checked-in date in terms of our location.
	lastCheckedIn := t.UTC().In(loc).Day()

	return today == lastCheckedIn
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
	content, err := json.MarshalIndent(scores, "", " ")
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
	if err := json.Unmarshal(b, &scores); err != nil {
		log.Fatalf("reading content in file %s  as JSON failed: %v", file, err)
	}
}

type GitHubUser struct {
	ID    int64  `json:"id"`
	Login string `json:"login"`
	Name  string `json:"name"`
}

func (p *Player) setGitHubDataFromToken() {
	// Create a new request using http
	req, err := http.NewRequest("GET", "https://api.github.com/user", nil)

	// add authorization header to the req
	req.Header.Add("Authorization", "token "+p.Token)
	req.Header.Add("Accept", "application/vnd.github.v3+json")

	// Send req using http Client
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Println("response from the github API errored\n[ERRO] -", err)
	}

	var user GitHubUser
	if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
		log.Println("decoding the response from the github api failed.\n[ERRO] -", err)
	}

	// Set the username.
	p.Username = user.Login

}

func main() {
	scores = ScoreData{
		mu:      sync.Mutex{},
		Players: []Player{},
	}
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

	mux := http.NewServeMux()
	mux.HandleFunc("/count", count)
	mux.HandleFunc("/", index)

	// TODO: skip this if in DEV mode, maybe set an env variable.
	// We need to generate the certificate.
	domain := "keyrace.app"
	fmt.Printf("Server is listening at https://%s..\n", domain)
	log.Fatal(http.Serve(autocert.NewListener(domain), mux))
}
