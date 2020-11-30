package main

import (
	"sort"
	"testing"
	"time"
)

func TestSort(t *testing.T) {
	// Create a new unsorted Scoreboard for a team.
	team := []Player{
		{Name: "bob", Score: 1},
		{Name: "charlie", Score: 2},
		{Name: "alice", Score: 34},
		{Name: "sue", Score: 874},
	}

	// We sort it.
	sort.Sort(byScore(team))

	// Now sue should be first, etc.
	if team[0].Name != "sue" {
		t.Fatalf("expected sue to be first, got: %s", team[0].Name)
	}
	if team[3].Name != "bob" {
		t.Fatalf("expected bob to be last, got: %s", team[3].Name)
	}
}

func TestIsToday(t *testing.T) {
	loc, err := time.LoadLocation("America/Los_Angeles")
	if err != nil {
		t.Fatalf("getting time zone location for America/Los_Angeles failed: %v", err)
	}

	times := map[string]bool{
		"2020-11-29T16:00:32+0000":                                                    false,
		"2020-11-29T16:00:32-0600":                                                    false,
		time.Now().Format("2006-01-02T15:04:05-0700"):                                 true,
		time.Now().UTC().In(loc).AddDate(0, 0, -1).Format("2006-01-02T15:04:05-0700"): false,
	}

	for timestr, expected := range times {
		ti, err := time.Parse("2006-01-02T15:04:05-0700", timestr)
		if err != nil {
			t.Fatal(err)
		}

		if expected != isToday(ti) {
			t.Fatalf("[%s] expected isToday %t, got %t", timestr, expected, isToday(ti))
		}
	}

}
