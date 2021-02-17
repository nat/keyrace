package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	http_logrus "github.com/improbable-eng/go-httpwares/logging/logrus"
	"github.com/improbable-eng/go-httpwares/logging/logrus/ctxlogrus"
	_ "github.com/mattn/go-sqlite3"
	"github.com/sirupsen/logrus"
	"golang.org/x/crypto/acme/autocert"
)

// Global variable for the database connection.
var db *sql.DB

type PlayerScore struct {
	Username string `json:"username"`
	Score    int64  `json:"score"`
}

type Player struct {
	ID       int64    `json:"id"`
	Username string   `json:"username"`
	Token    string   `json:"token"`
	Score    int64    `json:"score"`
	Follows  []string `json:"follows"`
}

func (p *Player) upsertInDB() error {
	tx, err := db.Begin()
	if err != nil {
		// Return early.
		return fmt.Errorf("beginning transaction in db failed: %v", err)
	}

	// Create the statement.
	var stmt *sql.Stmt
	if len(p.Username) == 0 {
		stmt, err = tx.Prepare(fmt.Sprintf(
			`INSERT INTO players(token,score,last_updated)
VALUES('%s',%d,datetime('now'))
ON CONFLICT(token) DO UPDATE SET score=excluded.score, last_updated=excluded.last_updated`,
			p.Token, p.Score))
		if err != nil {
			tx.Rollback()
			return fmt.Errorf("upserting player with token %q in db failed: %v", p.Token, err)
		}
	} else {
		// If we have a username, upsert that as well.
		stmt, err = tx.Prepare(fmt.Sprintf(
			`INSERT INTO players(token,username,score,last_updated,follows)
VALUES('%s','%s',%d,datetime('now'),'%s')
ON CONFLICT(username) DO UPDATE SET token=excluded.token, score=excluded.score, last_updated=excluded.last_updated, follows=excluded.follows`,
			p.Token, p.Username, p.Score, strings.Join(p.Follows, ",")))
		if err != nil {
			tx.Rollback()
			return fmt.Errorf("upserting player with token %q | username %q in db failed: %v", p.Token, p.Username, err)
		}
	}
	defer stmt.Close()

	// Execute the statement.
	if _, err := stmt.Exec(); err != nil {
		tx.Rollback()
		return fmt.Errorf("executing upsert player with token %q in db failed: %v", p.Token, err)
	}

	// Commit the transaction.
	if err := tx.Commit(); err != nil {
		tx.Rollback()
		return fmt.Errorf("commiting the transaction for player with token %q in db failed: %v", p.Token, err)
	}

	// If we sucessfully updated the player and their username is still empty,
	// let's get their data from the database.
	if len(p.Username) == 0 {
		var follows string
		if err := db.QueryRow("SELECT id,username,follows FROM players WHERE token=?", p.Token).Scan(&p.ID, &p.Username, &follows); err != nil {
			tx.Rollback()
			return fmt.Errorf("querying the db for player with token %q failed: %v", p.Token, err)
		}

		p.Follows = strings.Split(follows, ",")
	}

	logrus.WithFields(logrus.Fields{
		"username": p.Username,
		"token":    p.Token,
		"score":    p.Score,
	}).Info("updated player in database")
	return nil
}

func count(w http.ResponseWriter, req *http.Request) {
	ctxlogrus.Extract(req.Context()).Info("started request")

	// Get the token from the authorization header.
	ghToken := req.Header.Get("Authorization")
	splitToken := strings.Split(ghToken, "Bearer ")
	// Make sure we actually have a token.
	if len(splitToken) <= 1 {
		logrus.Warn("invalid GitHub token")
		return
	}
	ghToken = splitToken[1]

	count, err := strconv.ParseInt(req.URL.Query()["count"][0], 10, 64)
	if err != nil {
		logrus.Warnf("error parsing count: %v", err)
		return
	}

	onlyFollows := false
	onlyFollowsStr := req.URL.Query()["only_follows"]
	if len(onlyFollowsStr) > 0 {
		onlyFollows = true
	}

	// Create the player.
	player := Player{
		ID:       0,
		Username: "",
		Token:    ghToken,
		Score:    count,
		Follows:  []string{},
	}
	// Try to update the player in the database with just their token.
	if err := player.upsertInDB(); err != nil {
		// Let's get their username from GitHub since likely we
		// didn't already have it in the database.
		player.setGitHubDataFromToken()
		if err := player.upsertInDB(); err != nil {
			logrus.Warn(err)
			return
		}
	}

	// Make sure we have a Username, this should never be empty.
	if len(player.Username) == 0 {
		logrus.Warn("github username cannot be empty")
		return
	}

	// Print the user's leaderboard back out.
	leaderboard := player.getLeaderboard(onlyFollows)
	fmt.Fprintf(w, "%s", leaderboard)
}

func (p Player) getLeaderboard(onlyFollows bool) string {
	leaderboard := []PlayerScore{}

	// localtime depends on the localtime of the server.
	query := `SELECT username,score FROM players WHERE date(last_updated,'localtime') = date('now','localtime') ORDER BY score DESC LIMIT 20`
	if onlyFollows {
		// Make sure we get ourselves in the leaderboard as well.
		filter := fmt.Sprintf("'%s'", p.Username)
		for _, f := range p.Follows {
			filter += fmt.Sprintf(",'%s'", f)
		}

		query = fmt.Sprintf(`SELECT username,score FROM players WHERE date(last_updated,'localtime') = date('now','localtime') AND username IN (%s) ORDER BY score DESC LIMIT 20`, filter)
	}
	rows, err := db.Query(query)
	if err != nil {
		logrus.WithFields(logrus.Fields{
			"query": query,
		}).Warnf("querying the db for leaderboard for player with username %q failed: %v", p.Username, err)
	}
	defer rows.Close()

	for rows.Next() {
		player := PlayerScore{}
		if err := rows.Scan(&player.Username, &player.Score); err != nil {
			logrus.Warnf("failed to scan row for player for leaderboard: %v", err)
		}

		if len(player.Username) > 0 {
			// Add it to our array.
			leaderboard = append(leaderboard, player)
		}
	}

	str, err := json.Marshal(leaderboard)
	if err != nil {
		logrus.Warnf("marshaling the leaderboard to JSON failed: %v", err)
	}

	return string(str)
}

func removeFromSlice(slice []Player, index int) []Player {
	return append(slice[:index], slice[index+1:]...)
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

type GitHubUser struct {
	ID    int64  `json:"id"`
	Login string `json:"login"`
	Name  string `json:"name"`
}

func (p *Player) setGitHubDataFromToken() {
	resp := p.doGitHubCall("user")
	var user GitHubUser
	if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
		logrus.Warnf("decoding the response from the github api failed: %v", err)
	}

	// Set the username.
	p.Username = user.Login

	// Get who the user follows.
	resp = p.doGitHubCall("user/following")
	var users []GitHubUser
	if err := json.NewDecoder(resp.Body).Decode(&users); err != nil {
		logrus.Warnf("decoding the response from the github api failed: %v", err)
	}

	// Set the follows.
	p.Follows = []string{}
	for _, u := range users {
		p.Follows = append(p.Follows, u.Login)
	}

}

func (p Player) doGitHubCall(endpoint string) *http.Response {
	req, err := http.NewRequest("GET", fmt.Sprintf("https://api.github.com/%s", endpoint), nil)

	// add authorization header to the req
	req.Header.Add("Authorization", "token "+p.Token)
	req.Header.Add("Accept", "application/vnd.github.v3+json")

	// Send req using http Client
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		logrus.WithFields(logrus.Fields{
			"endpoint": endpoint,
		}).Warnf("response from the github API errored: %v", err)
	}

	return resp
}

func main() {
	// On ^C, or SIGTERM gracefully handle exit.
	signals := make(chan os.Signal)
	signal.Notify(signals, os.Interrupt)
	signal.Notify(signals, syscall.SIGTERM)
	go func() {
		for sig := range signals {
			// Close the database.
			db.Close()
			logrus.Infof("received signal %s, exiting", sig.String())
			os.Exit(0)
		}
	}()

	// Get the current working directory.
	curdir, err := os.Getwd()
	if err != nil {
		logrus.Fatalf("getting the current working directory failed: %v", err)
	}

	// Open the database.
	dbPath := filepath.Join(curdir, "keyrace.db?mode=rwc&_busy_timeout=10000")
	db, err = sql.Open("sqlite3", dbPath)
	if err != nil {
		logrus.WithFields(logrus.Fields{
			"path": dbPath,
		}).Fatalf("opening the database failed: %v", err)
	}
	logrus.WithFields(logrus.Fields{
		"path": dbPath,
	}).Info("opened database")

	// Create our table.
	createTableStatement := `
	CREATE TABLE IF NOT EXISTS players (
		id INTEGER NOT NULL PRIMARY KEY,
		username TEXT NOT NULL UNIQUE,
		token TEXT NOT NULL UNIQUE,
		score INTEGER NOT NULL DEFAULT 0,
		last_updated TEXT NOT NULL,
		follows TEXT NOT NULL
	);`
	_, err = db.Exec(createTableStatement)
	if err != nil {
		logrus.Fatalf("creating the sqlite table failed: %v -> %s", err, createTableStatement)
	}
	logrus.WithFields(logrus.Fields{
		"table": "players",
	}).Info("created database table if it didn't exist")

	mux := http.NewServeMux()
	mux.HandleFunc("/count", count)
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "https://github.com/nat/keyrace", 301)
	})

	// Setup the logger.
	muxLogger := http_logrus.Middleware(logrus.WithField("type", "request"))(mux)

	// TODO: skip this if in DEV mode, maybe set an env variable.
	// We need to generate the certificate.
	domain := "keyrace.app"
	logrus.Infof("Server is listening at https://%s..", domain)
	logrus.Fatal(http.Serve(autocert.NewListener(domain), muxLogger))
}
