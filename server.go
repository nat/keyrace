package main

import (
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"sync"
	"time"
)

var scoreboards map[string]*team

type team struct {
	// We have a mutex here so we can add and update players safely.
	mu      sync.Mutex
	players []player
}

// byScore implements sort.Interface for []player based on
// the score field.
type byScore []player

type player struct {
	name              string
	score             int
	timeLastCheckedIn time.Time
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
	return s[i].score > s[j].score
}

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
	teamName := keys[0]

	if _, ok := scoreboards[teamName]; !ok {
		scoreboards[teamName] = &team{}
	}

	scoreboard, ok := scoreboards[teamName]
	if ok {
		// Find the matching player.
		for index, player := range scoreboard.players {
			if player.name == "name" {
				// Update the player and break the loop, returning early.
				fmt.Fprintf(w, "updated count for %s from %d to %d\n", name, player.score, count)
				player.score = count
				player.timeLastCheckedIn = time.Now()

				// Lock the mutex while we update the count.
				scoreboards[teamName].mu.Lock()
				scoreboards[teamName].players[index] = player
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
		scoreboards[teamName].players = append(scoreboards[teamName].players, player{
			name:              name,
			score:             count,
			timeLastCheckedIn: time.Now(),
		})
		// Unlock the mutex since we are done updating.
		scoreboards[teamName].mu.Unlock()
	}
}

func index(w http.ResponseWriter, req *http.Request) {
	fmt.Println(req.URL.String())

	team := req.URL.Query()["team"][0]
	scoreboard := scoreboards[team]

	sort.Sort(byScore(scoreboard.players))

	for _, player := range scoreboard.players {
		fmt.Fprintf(w, "%-20s%d\t%s\n", player.name, player.score, humanTime(player.timeLastCheckedIn))
	}
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

func main() {
	scoreboards = make(map[string]*team)

	http.HandleFunc("/count", count)
	http.HandleFunc("/", index)

	http.ListenAndServe(":80", nil)
}
