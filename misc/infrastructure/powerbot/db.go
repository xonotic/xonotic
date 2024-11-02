package main

import (
	"database/sql"
	"fmt"
	"maunium.net/go/mautrix/id"
	_ "modernc.org/sqlite"
	"time"
)

type State int

const (
	Kicked    State = -1
	NotActive State = 0
	Idle      State = 1
	Active    State = 2
)

type Score struct {
	LastEvent    time.Time
	CurrentState State
	Idle         time.Duration
	Active       time.Duration
}

const dbSchema = `
CREATE TABLE IF NOT EXISTS room_users (
  room_id STRING NOT NULL,
  user_id STRING NOT NULL,
  state_time TIMESTAMP NOT NULL,
  state INT NOT NULL,
  idle_nsec INT64 NOT NULL,
  active_nsec INT64 NOT NULL,
  PRIMARY KEY(room_id, user_id)
);
`

const fetchStateQuery = `
SELECT state_time, state, idle_nsec, active_nsec
FROM room_users
WHERE room_id = ?
  AND user_id = ?
`

const insertStateQuery = `
INSERT INTO room_users(room_id, user_id, state_time, state, idle_nsec, active_nsec)
VALUES(?, ?, ?, ?, 0.0, 0.0)
`

const updateStateQuery = `
UPDATE room_users
SET state_time = ?, state = ?, idle_nsec = ?, active_nsec = ?
WHERE room_id = ?
  AND user_id = ?
`

const fetchUserScoresQuery = `
SELECT user_id, state_time, state, idle_nsec, active_nsec
FROM room_users
WHERE room_id = ?
`

var db *sql.DB

func InitDatabase() error {
	var err error
	db, err = sql.Open("sqlite", "users.sqlite")
	if err != nil {
		return fmt.Errorf("could not open SQLite database: %v", err)
	}
	_, err = db.Exec(dbSchema)
	if err != nil {
		return fmt.Errorf("could not set SQLite database schema: %v", err)
	}
	return nil
}

func CloseDatabase() error {
	return db.Close()
}

func queryUserScores(room id.RoomID, now time.Time) (map[id.UserID]*Score, error) {
	var users map[id.UserID]*Score
	err := retryPolicy(func() error {
		rows, err := db.Query(fetchUserScoresQuery, room)
		if err != nil {
			return fmt.Errorf("could not query users: %v", err)
		}
		users = map[id.UserID]*Score{}
		for rows.Next() {
			var user id.UserID
			var score Score
			if err := rows.Scan(&user, &score.LastEvent, &score.CurrentState, &score.Idle, &score.Active); err != nil {
				return fmt.Errorf("could not scan users query result: %v", err)
			}
			newScore := advanceScore(score, now)
			users[user] = &newScore
		}
		if err := rows.Err(); err != nil {
			return fmt.Errorf("could not read users: %v", err)
		}
		return nil
	})
	return users, err
}

func advanceScore(score Score, now time.Time) Score {
	if !now.After(score.LastEvent) {
		return score
	}
	dt := now.Sub(score.LastEvent)
	switch score.CurrentState {
	case Idle:
		score.Idle += dt
	case Active:
		score.Active += dt
	case Kicked:
		score.Idle = 0
		score.Active = 0
	}
	return score
}

func retryPolicy(f func() error) error {
	var err error
	for attempt := 0; attempt < 12; attempt++ {
		err = f()
		if err == nil {
			return nil
		}
		time.Sleep(time.Millisecond * time.Duration(1<<attempt))
	}
	return err
}

func inTx(db *sql.DB, f func(tx *sql.Tx) error) error {
	tx, err := db.Begin()
	if err != nil {
		return fmt.Errorf("failed to create transaction: %v", err)
	}
	err = f(tx)
	if err != nil {
		tx.Rollback()
		return err
	}
	return tx.Commit()
}

func writeUserStateAt(room id.RoomID, user id.UserID, now time.Time, maxPrevState, state State) error {
	return retryPolicy(func() error {
		return inTx(db, func(tx *sql.Tx) error {
			row := tx.QueryRow(fetchStateQuery, room, user)
			var score Score
			err := row.Scan(&score.LastEvent, &score.CurrentState, &score.Idle, &score.Active)
			if err == sql.ErrNoRows {
				_, err = tx.Exec(insertStateQuery, room, user, now, state)
				if err != nil {
					return fmt.Errorf("failed to set state for new user: %v", err)
				}
				return nil
			} else {
				if err != nil {
					return fmt.Errorf("failed to fetch state for user: %v", err)
				}
				if now.After(score.LastEvent) {
					if score.CurrentState > maxPrevState {
						score.CurrentState = maxPrevState
					}
					score = advanceScore(score, now)
					_, err = tx.Exec(updateStateQuery, now, state, score.Idle, score.Active, room, user)
					if err != nil {
						return fmt.Errorf("failed to update state for new user: %v", err)
					}
					return nil
				} else {
					_, err = tx.Exec(updateStateQuery, score.LastEvent, state, score.Idle, score.Active, room, user)
					if err != nil {
						return fmt.Errorf("failed to update state for new user: %v", err)
					}
					return nil
				}
			}
		})
	})
}
