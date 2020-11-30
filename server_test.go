package main

import (
	"sort"
	"testing"
)

func TestSort(t *testing.T) {
	// Create a new unsorted scoreboard for a team.
	team := []player{
		{name: "bob", score: 1},
		{name: "charlie", score: 2},
		{name: "alice", score: 34},
		{name: "sue", score: 874},
	}

	// We sort it.
	sort.Sort(byScore(team))

	// Now sue should be first, etc.
	if team[0].name != "sue" {
		t.Fatalf("expected sue to be first, got: %s", team[0].name)
	}
	if team[3].name != "bob" {
		t.Fatalf("expected bob to be last, got: %s", team[3].name)
	}
}
