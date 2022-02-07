package main

import (
	"github.com/google/go-cmp/cmp"
	"log"
	"math"
	"maunium.net/go/mautrix"
	"maunium.net/go/mautrix/event"
	"maunium.net/go/mautrix/id"
	"time"
)

const (
	idleScore   = 1
	activeScore = 100
	activeTime  = 5 * time.Minute
	// 15 minutes idling = PL 1.
	minPowerScore = 15 * 60 * idleScore
	minPowerLevel = 1
	// 1 year fulltime active dev = PL 10.
	maxPowerScore = 3600 * (365*24*idleScore + 8*261*(activeScore-idleScore))
	maxPowerLevel = 9
	// Expire power level if no event for 1 month. Level comes back on next event, including join.
	powerExpireTime = time.Hour * 24 * 30
	// Maximum count of ACL entries. Should avoid hitting the 64k limit.
	maxPowerLevelEntries = 2048
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

func syncPowerLevels(client *mautrix.Client, room id.RoomID, roomGroup []id.RoomID, scores map[id.RoomID]map[id.UserID]*Score, force bool) {
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
			if _, found := roomUsers[room][user]; !found && score.CurrentState != NotActive {
				log.Printf("Pruning long inactive user %v from room %v.", user, room)
				setUserStateAt(room, user, time.Now(), NotActive, NotActive)
				score.CurrentState = NotActive
			}
		}
	}
	newRoomLevels := *roomLevels
	newRoomLevels.Users = make(map[id.UserID]int)
	for user, level := range roomLevels.Users {
		if level == roomLevels.UsersDefault {
			continue
		}
		// TODO: Also skip users who aren't in the room for ages.
		score := scores[room][user]
		if level >= minPowerLevel && level <= maxPowerLevel && score.CurrentState == NotActive && time.Now().After(score.LastEvent.Add(powerExpireTime)) {
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
			if otherRoom == room {
				continue
			}
			otherScore := scores[otherRoom][user]
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
		if level > prevLevel {
			log.Printf("room %v user %v power level: INCREASE %v -> %v (%v, %v)", room, user, prevLevel, level, raw, score)
			newRoomLevels.Users[user] = level
			dirty = true
		} else if level < prevLevel {
			log.Printf("room %v user %v power level: SKIP %v -> %v (%v, %v)", room, user, prevLevel, level, raw, score)
		} else {
			log.Printf("room %v user %v power level: KEEP %v -> %v (%v, %v)", room, user, prevLevel, level, raw, score)
		}
	}
	clearPowerLevel := minPowerLevel
	for len(newRoomLevels.Users) > maxPowerLevelEntries && clearPowerLevel <= maxPowerLevel {
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
		_, err := client.SendStateEvent(room, event.StatePowerLevels, "", newRoomLevels)
		if err != nil {
			log.Printf("Failed to update power levels: %v", err)
		}
	} else {
		log.Printf("room %v nothing to update", room)
	}
}
