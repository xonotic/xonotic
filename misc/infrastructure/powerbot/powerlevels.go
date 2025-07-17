package main

import (
	"context"
	"encoding/json"
	"github.com/google/go-cmp/cmp"
	"log"
	"math"
	"maunium.net/go/mautrix"
	"maunium.net/go/mautrix/event"
	"maunium.net/go/mautrix/id"
	"reflect"
	"time"
)

const (
	idleScore   = 1
	activeScore = 100
	activeTime  = 5 * time.Minute
	// 15 minutes idling = PL 1.
	minPowerScore = 15 * 60 * idleScore
	minPowerLevel = 1
	// 1 year fulltime active dev = PL 9.
	maxPowerScore = 3600 * (365*24*idleScore + 8*261*(activeScore-idleScore))
	maxPowerLevel = 9
	// Do not touch users outside this range.
	minApplyLevel = 0
	maxApplyLevel = 9
	// Expire power level if no event for 1 month. Level comes back on next event, including join.
	powerExpireTime = time.Hour * 24 * 30
	// Maximum size of powerlevels message. This is a quarter of the expected Matrix limit.
	maxPowerLevelBytes = (65535 - 1024) / 4
)

func logPowerLevelBounds() {
	for i := minPowerLevel; i <= maxPowerLevel; i++ {
		score := minPowerScore * math.Pow(maxPowerScore/minPowerScore, float64(i-minPowerLevel)/float64(maxPowerLevel-minPowerLevel))
		log.Printf("Power level %d requires score %v (= %v idle or %v active).",
			i, score,
			time.Duration(float64(time.Second)*score/idleScore),
			time.Duration(float64(time.Second)*score/activeScore),
		)
	}
}

func computePowerLevel(def int, score Score) (int, float64) {
	points := score.Idle.Seconds()*idleScore + score.Active.Seconds()*activeScore
	if points <= 0 {
		return def, math.Inf(-1)
	}
	raw := minPowerLevel + (maxPowerLevel-minPowerLevel)*math.Log(points/minPowerScore)/math.Log(maxPowerScore/minPowerScore)
	if raw < minPowerLevel {
		return def, raw
	}
	if points > maxPowerScore {
		return maxPowerLevel, raw
	}
	return int(math.Floor(raw)), raw
}

func allPowerLevels(roomLevels *event.PowerLevelsEventContent) []int {
	ret := make([]int, 0, len(roomLevels.Events)+5)
	for _, level := range roomLevels.Events {
		ret = append(ret, level)
	}
	ret = append(ret, roomLevels.EventsDefault)
	if roomLevels.InvitePtr != nil {
		ret = append(ret, *roomLevels.InvitePtr)
	}
	if roomLevels.KickPtr != nil {
		ret = append(ret, *roomLevels.KickPtr)
	}
	if roomLevels.BanPtr != nil {
		ret = append(ret, *roomLevels.BanPtr)
	}
	if roomLevels.RedactPtr != nil {
		ret = append(ret, *roomLevels.RedactPtr)
	}
	return ret
}

func syncPowerLevels(ctx context.Context, client *mautrix.Client, room id.RoomID, roomGroup []Room, scores map[id.RoomID]map[id.UserID]*Score, force bool) {
	roomLevels := roomPowerLevels[room]
	if roomLevels == nil {
		log.Printf("trying to ensure power levels for room %v, but did not get power level map yet", room)
		return
	}
	tryUpdate := force
	for _, level := range allPowerLevels(roomLevels) {
		if minPowerLevel <= level && level <= maxPowerLevel {
			tryUpdate = true
		}
	}
	if !tryUpdate {
		log.Printf("room %v skipping because PLs currently do not matter", room)
		return
	}
	log.Printf("room %v considering to update PLs", room)
	if fullySynced {
		for user, score := range scores[room] {
			// Expire users that for some reason did not get pruned from the database.
			// This may cause them to lose their power level below.
			if _, found := roomUsers[room][user]; !found && score.CurrentState != NotActive && score.CurrentState != Kicked {
				log.Printf("Pruning long inactive user %v from room %v.", user, room)
				setUserStateAt(room, user, time.Now(), NotActive, NotActive)
				score.CurrentState = NotActive
			}
		}
	}
	newRoomLevels := makeDefaultsExplicit(roomLevels)
	newRoomLevels.Users = make(map[id.UserID]int)
	for user, level := range roomLevels.Users {
		if level == roomLevels.UsersDefault {
			continue
		}
		// TODO: Also skip users who aren't in the room for ages.
		score := scores[room][user]
		if level >= minPowerLevel && level <= maxPowerLevel && (score == nil || (score.CurrentState == NotActive && time.Now().After(score.LastEvent.Add(powerExpireTime)))) {
			// User is inactive - prune them from the power level list. Saves space.
			// But this doesn't mark the list dirty as there is no need to send an update.
			log.Printf("room %v user %v power level: PRUNE %v (%v)", room, user, level, score)
			continue
		}
		newRoomLevels.Users[user] = level
	}
	dirty := false
	log.Printf("room %v", room)
	for user, score := range scores[room] {
		if score.CurrentState == NotActive {
			// Do not add/bump power levels for users not in the room.
			continue
		}
		prevLevel := roomLevels.Users[user]
		level, raw := computePowerLevel(roomLevels.UsersDefault, *score)
		for _, otherRoom := range roomGroup {
			if otherRoom.ID == room {
				continue
			}
			otherScore := scores[otherRoom.ID][user]
			if otherScore == nil {
				continue
			}
			otherLevel, otherRaw := computePowerLevel(roomLevels.UsersDefault, *otherScore)
			if otherLevel > level {
				level = otherLevel
			}
			if otherRaw > raw {
				raw = otherRaw
			}
		}
		if prevLevel < minApplyLevel {
			log.Printf("room %v user %v power level: SKIP_TOO_LOW %v -> %v (%v, %v)", room, user, prevLevel, level, raw, score)
		} else if prevLevel > maxApplyLevel {
			log.Printf("room %v user %v power level: SKIP_TOO_HIGH %v -> %v (%v, %v)", room, user, prevLevel, level, raw, score)
		} else if level < prevLevel {
			log.Printf("room %v user %v power level: SKIP_WOULD_LOWER %v -> %v (%v, %v)", room, user, prevLevel, level, raw, score)
		} else if level > prevLevel {
			log.Printf("room %v user %v power level: INCREASE %v -> %v (%v, %v)", room, user, prevLevel, level, raw, score)
			newRoomLevels.Users[user] = level
			dirty = true
		} else {
			log.Printf("room %v user %v power level: KEEP %v -> %v (%v, %v)", room, user, prevLevel, level, raw, score)
		}
	}
	clearPowerLevel := minPowerLevel
	for clearPowerLevel <= maxPowerLevel {
		j, err := json.Marshal(newRoomLevels)
		if err != nil {
			log.Printf("could not marshal newRoomLevels: %v", err)
			break
		}
		if len(j) <= maxPowerLevelBytes {
			// No need to trim.
			break
		}
		log.Printf("room %v not including power level %d to reduce message size", clearPowerLevel)
		for user, level := range newRoomLevels.Users {
			if level == clearPowerLevel {
				delete(newRoomLevels.Users, user)
				dirty = true
			}
		}
		clearPowerLevel++
	}
	if dirty {
		diff := cmp.Diff(roomLevels.Users, newRoomLevels.Users)
		log.Printf("room %v power level update:\n%v", room, diff)
		_, err := client.SendStateEvent(ctx, room, event.StatePowerLevels, "", newRoomLevels)
		if err != nil {
			log.Printf("Failed to update power levels: %v", err)
		}
	} else {
		log.Printf("room %v nothing to update", room)
	}
}

type powerLevelsWithDefaults struct {
	// This struct is a copy of the public stuff in event.PowerLevelsEventContent,
	// but with omitempty removed on users_default and events_default to work around
	// https://github.com/matrix-org/dendrite/issues/2983
	Users           map[id.UserID]int              `json:"users,omitempty"`
	UsersDefault    int                            `json:"users_default"`
	Events          map[string]int                 `json:"events,omitempty"`
	EventsDefault   int                            `json:"events_default"`
	Notifications   *event.NotificationPowerLevels `json:"notifications,omitempty"`
	StateDefaultPtr *int                           `json:"state_default,omitempty"`
	InvitePtr       *int                           `json:"invite,omitempty"`
	KickPtr         *int                           `json:"kick,omitempty"`
	BanPtr          *int                           `json:"ban,omitempty"`
	RedactPtr       *int                           `json:"redact,omitempty"`
	HistoricalPtr   *int                           `json:"historical,omitempty"`
}

func makeDefaultsExplicit(roomLevels *event.PowerLevelsEventContent) *powerLevelsWithDefaults {
	// Copying over all exported fields using reflect.
	// Doing it this way so if a new field is added to event.PowerLevelsEventContent, this code panics.
	var withDefaults powerLevelsWithDefaults
	src := reflect.ValueOf(roomLevels).Elem()
	dst := reflect.ValueOf(&withDefaults).Elem()
	for i := 0; i < src.Type().NumField(); i++ {
		srcField := src.Type().Field(i)
		if !srcField.IsExported() {
			continue
		}
		dst.FieldByName(srcField.Name).Set(src.Field(i))
	}
	return &withDefaults
}
