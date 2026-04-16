package ecs

import "sync"

// PlayerComp links an entity to a Gateway session and account.
//
// CharName (Phase S-7) holds the character's in-game display name.
// Populated by Lua on world entry (player.set_name); used by chat whisper
// routing and group member display. Empty string before CM_ENTER_WORLD.
type PlayerComp struct {
	AccountID    int64
	Account      string
	GatewaySeqID uint64
	RemoteAddr   string
	CharName     string
}

// PositionComp holds the in-world spatial state of an entity.
type PositionComp struct {
	WorldID int32
	MapNum  int32
	X, Y, Z float32
	Heading byte
}

// NpcComp links an entity to its NPC template and AI configuration.
type NpcComp struct {
	TemplateID int32
	Level      int32
	AIScript   string // Lua AI behaviour script name (e.g. "patrol")
}

// BuffEntry represents a single active buff or DoT on an entity.
// DoT entries have IsDot=true; damage is applied each game tick.
type BuffEntry struct {
	BuffID        int32
	IsDot         bool
	DamagePerTick float64 // DoT only: damage applied per tick
	Element       string  // DoT element ("fire", "bleed", "physical")
	ExpiresAtTick int64   // game tick after which the buff is removed
}

// StatsComp holds arbitrary named floating-point stats for any entity type.
// Key examples: "hp", "mp", "fp", "level", "world_id", "map_num", "char_id".
type StatsComp map[string]float64

// World is the root ECS container — thread-safe component stores per type.
// All exported methods acquire the appropriate lock; never hold the lock in
// callbacks or SP calls to avoid deadlocks.
type World struct {
	mu    sync.RWMutex
	alive map[Entity]struct{}

	// Component stores — extended per phase.
	Players   map[Entity]*PlayerComp
	Positions map[Entity]*PositionComp
	NPCs      map[Entity]*NpcComp
	Stats     map[Entity]StatsComp

	// Buffs holds active buff and DoT entries per entity.
	Buffs map[Entity][]*BuffEntry

	// BySeqID is a reverse index for O(1) lookup from Gateway session ID to entity.
	// Maintained automatically by SetPlayer and DestroyEntity.
	BySeqID map[uint64]Entity
}

// NewWorld returns an empty, ready-to-use World.
func NewWorld() *World {
	return &World{
		alive:     make(map[Entity]struct{}),
		Players:   make(map[Entity]*PlayerComp),
		Positions: make(map[Entity]*PositionComp),
		NPCs:      make(map[Entity]*NpcComp),
		Stats:     make(map[Entity]StatsComp),
		Buffs:     make(map[Entity][]*BuffEntry),
		BySeqID:   make(map[uint64]Entity),
	}
}

// NewEntity allocates a new entity and marks it alive.
func (w *World) NewEntity() Entity {
	id := newID()
	w.mu.Lock()
	w.alive[id] = struct{}{}
	w.mu.Unlock()
	return id
}

// DestroyEntity removes all components and marks the entity dead.
func (w *World) DestroyEntity(e Entity) {
	w.mu.Lock()
	// Remove reverse index before deleting PlayerComp.
	if p, ok := w.Players[e]; ok {
		delete(w.BySeqID, p.GatewaySeqID)
	}
	delete(w.alive, e)
	delete(w.Players, e)
	delete(w.Positions, e)
	delete(w.NPCs, e)
	delete(w.Stats, e)
	delete(w.Buffs, e)
	w.mu.Unlock()
}

// SetPlayer stores a PlayerComp for entity e and updates the BySeqID index.
func (w *World) SetPlayer(e Entity, c *PlayerComp) {
	w.mu.Lock()
	w.Players[e] = c
	w.BySeqID[c.GatewaySeqID] = e
	w.mu.Unlock()
}

// GetPlayer returns the PlayerComp for entity e, if present.
func (w *World) GetPlayer(e Entity) (*PlayerComp, bool) {
	w.mu.RLock()
	defer w.mu.RUnlock()
	c, ok := w.Players[e]
	return c, ok
}

// SetPosition stores a PositionComp for entity e.
func (w *World) SetPosition(e Entity, c *PositionComp) {
	w.mu.Lock()
	w.Positions[e] = c
	w.mu.Unlock()
}

// GetPosition returns the PositionComp for entity e, if present.
func (w *World) GetPosition(e Entity) (*PositionComp, bool) {
	w.mu.RLock()
	defer w.mu.RUnlock()
	c, ok := w.Positions[e]
	return c, ok
}

// Count returns the number of live entities.
func (w *World) Count() int {
	w.mu.RLock()
	defer w.mu.RUnlock()
	return len(w.alive)
}

// SetNpc stores a NpcComp for entity e.
func (w *World) SetNpc(e Entity, c *NpcComp) {
	w.mu.Lock()
	w.NPCs[e] = c
	w.mu.Unlock()
}

// GetNpc returns the NpcComp for entity e, if present.
func (w *World) GetNpc(e Entity) (*NpcComp, bool) {
	w.mu.RLock()
	defer w.mu.RUnlock()
	c, ok := w.NPCs[e]
	return c, ok
}

// SetStat writes a single named stat for entity e.
func (w *World) SetStat(e Entity, key string, val float64) {
	w.mu.Lock()
	if w.Stats[e] == nil {
		w.Stats[e] = make(StatsComp)
	}
	w.Stats[e][key] = val
	w.mu.Unlock()
}

// GetStat reads a single named stat for entity e.
// Returns (0, false) if the entity has no stats component or the key is absent.
func (w *World) GetStat(e Entity, key string) (float64, bool) {
	w.mu.RLock()
	defer w.mu.RUnlock()
	sc, ok := w.Stats[e]
	if !ok {
		return 0, false
	}
	v, ok := sc[key]
	return v, ok
}

// AddBuff adds or refreshes a BuffEntry on entity e.
// If an entry with the same BuffID already exists it is replaced (buff refresh).
func (w *World) AddBuff(e Entity, entry *BuffEntry) {
	w.mu.Lock()
	defer w.mu.Unlock()
	list := w.Buffs[e]
	for i, b := range list {
		if b.BuffID == entry.BuffID {
			list[i] = entry
			return
		}
	}
	w.Buffs[e] = append(list, entry)
}

// GetBuffs returns a snapshot of all active BuffEntries for entity e.
func (w *World) GetBuffs(e Entity) []*BuffEntry {
	w.mu.RLock()
	defer w.mu.RUnlock()
	src := w.Buffs[e]
	if len(src) == 0 {
		return nil
	}
	result := make([]*BuffEntry, len(src))
	copy(result, src)
	return result
}

// RemoveExpiredBuffs removes all entries with ExpiresAtTick <= currentTick.
// Returns the removed entries so callers can react (e.g. broadcast buff-off packet).
func (w *World) RemoveExpiredBuffs(e Entity, currentTick int64) []*BuffEntry {
	w.mu.Lock()
	defer w.mu.Unlock()
	list := w.Buffs[e]
	if len(list) == 0 {
		return nil
	}
	var expired []*BuffEntry
	active := list[:0]
	for _, b := range list {
		if b.ExpiresAtTick <= currentTick {
			expired = append(expired, b)
		} else {
			active = append(active, b)
		}
	}
	if len(expired) > 0 {
		// Avoid shared backing array; allocate fresh slice.
		w.Buffs[e] = append([]*BuffEntry(nil), active...)
	}
	return expired
}

// GetEntityBySeqID returns the entity that owns the given Gateway session ID.
// Returns (0, false) if no player is logged in with that session.
func (w *World) GetEntityBySeqID(seqID uint64) (Entity, bool) {
	w.mu.RLock()
	defer w.mu.RUnlock()
	e, ok := w.BySeqID[seqID]
	return e, ok
}

// FindPlayerByName performs a case-sensitive linear scan of PlayerComp.CharName
// and returns the first matching entity. Whisper routing is rare enough that
// a reverse index is not yet justified (O(n) on <2000 players per shard).
// Returns (0, false) if no player with that name is currently online.
func (w *World) FindPlayerByName(name string) (Entity, bool) {
	if name == "" {
		return 0, false
	}
	w.mu.RLock()
	defer w.mu.RUnlock()
	for e, p := range w.Players {
		if p.CharName == name {
			return e, true
		}
	}
	return 0, false
}

// AllPlayers returns a snapshot of entity IDs for every entity that has a
// PlayerComp (i.e., all currently connected game sessions).
func (w *World) AllPlayers() []Entity {
	w.mu.RLock()
	defer w.mu.RUnlock()
	result := make([]Entity, 0, len(w.Players))
	for e := range w.Players {
		result = append(result, e)
	}
	return result
}

// AllNPCs returns a snapshot of entity IDs for every entity that has an NpcComp.
func (w *World) AllNPCs() []Entity {
	w.mu.RLock()
	defer w.mu.RUnlock()
	result := make([]Entity, 0, len(w.NPCs))
	for e := range w.NPCs {
		result = append(result, e)
	}
	return result
}

// GetNearby returns all live entities within radius metres of entity e.
// Entity e itself is excluded from the result.
// Returns nil if e has no PositionComp.
// Time complexity: O(n) in the number of entities with positions.
func (w *World) GetNearby(e Entity, radius float32) []Entity {
	w.mu.RLock()
	defer w.mu.RUnlock()

	center, ok := w.Positions[e]
	if !ok {
		return nil
	}

	r2 := radius * radius
	var result []Entity
	for id, pos := range w.Positions {
		if id == e {
			continue
		}
		dx := pos.X - center.X
		dy := pos.Y - center.Y
		dz := pos.Z - center.Z
		if dx*dx+dy*dy+dz*dz <= r2 {
			result = append(result, id)
		}
	}
	return result
}

// GetNearbyPlayers returns live player entities within radius metres of e.
// Equivalent to GetNearby filtered by PlayerComp presence; excludes NPCs and
// entity e itself. Used for chat local/shout broadcast in Phase S-7.
func (w *World) GetNearbyPlayers(e Entity, radius float32) []Entity {
	w.mu.RLock()
	defer w.mu.RUnlock()

	center, ok := w.Positions[e]
	if !ok {
		return nil
	}

	r2 := radius * radius
	var result []Entity
	for id, pos := range w.Positions {
		if id == e {
			continue
		}
		if _, isPlayer := w.Players[id]; !isPlayer {
			continue
		}
		dx := pos.X - center.X
		dy := pos.Y - center.Y
		dz := pos.Z - center.Z
		if dx*dx+dy*dy+dz*dz <= r2 {
			result = append(result, id)
		}
	}
	return result
}
