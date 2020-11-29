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
	sort.Sort(byCount(team))

	// Now sue should be first, etc.
	if team[0].name != "sue" {
		t.Fatalf("expected sue to be first")
	}
}
