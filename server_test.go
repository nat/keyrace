package main

import (
	"sort"
	"testing"
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
