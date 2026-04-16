// Package ecs provides a minimal Entity-Component-System for the World Engine.
//
// Design principles:
//   - Entity is a unique uint64 ID; component stores are plain maps.
//   - Thread-safe via sync.RWMutex; optimise for read-heavy workloads.
//   - Phase S-2 includes PlayerComp and PositionComp; later phases add more.
//   - No archetype or batch optimisation — fine for < 5000 CCU.
package ecs

import "sync/atomic"

// Entity is the unique identifier for a game object.
// Allocate with World.NewEntity(); release with World.DestroyEntity().
type Entity uint64

// globalCounter is the monotonically-increasing entity ID source.
// Using a package-level counter means IDs are unique across World instances.
var globalCounter atomic.Uint64

// newID returns the next unique entity ID.
func newID() Entity {
	return Entity(globalCounter.Add(1))
}
