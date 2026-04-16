package ecs

import (
	"testing"
)

// TestFindPlayerByName_Basic verifies that a player with CharName "Alice" is
// found by FindPlayerByName.
func TestFindPlayerByName_Basic(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()
	w.SetPlayer(e, &PlayerComp{GatewaySeqID: 1, CharName: "Alice"})

	got, ok := w.FindPlayerByName("Alice")
	if !ok {
		t.Fatal("expected FindPlayerByName to return true")
	}
	if got != e {
		t.Errorf("expected entity %v, got %v", e, got)
	}
}

// TestFindPlayerByName_NotFound verifies that an absent name returns (0, false).
func TestFindPlayerByName_NotFound(t *testing.T) {
	w := NewWorld()

	got, ok := w.FindPlayerByName("Nobody")
	if ok {
		t.Error("expected ok=false for absent name")
	}
	if got != 0 {
		t.Errorf("expected entity 0, got %v", got)
	}
}

// TestFindPlayerByName_EmptyName verifies the documented short-circuit:
// empty string always returns (0, false) regardless of registered players.
func TestFindPlayerByName_EmptyName(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()
	// Even if a player somehow has CharName == "", the guard must fire first.
	w.SetPlayer(e, &PlayerComp{GatewaySeqID: 2, CharName: ""})

	got, ok := w.FindPlayerByName("")
	if ok {
		t.Error("expected ok=false for empty name query")
	}
	if got != 0 {
		t.Errorf("expected entity 0, got %v", got)
	}
}

// TestFindPlayerByName_CaseSensitive verifies that "alice" does not match "Alice".
func TestFindPlayerByName_CaseSensitive(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()
	w.SetPlayer(e, &PlayerComp{GatewaySeqID: 3, CharName: "Alice"})

	got, ok := w.FindPlayerByName("alice")
	if ok {
		t.Error("expected ok=false for wrong-case query")
	}
	if got != 0 {
		t.Errorf("expected entity 0, got %v", got)
	}
}

// TestGetNearbyPlayers_ExcludesNPCs verifies that NPCs are omitted from the
// result even when they are within the search radius.
func TestGetNearbyPlayers_ExcludesNPCs(t *testing.T) {
	w := NewWorld()

	// player1 at origin.
	p1 := w.NewEntity()
	w.SetPlayer(p1, &PlayerComp{GatewaySeqID: 10})
	w.SetPosition(p1, &PositionComp{X: 0, Y: 0, Z: 0})

	// NPC at (5, 0, 0) — within 50 m but must be excluded.
	npc := w.NewEntity()
	w.SetNpc(npc, &NpcComp{TemplateID: 999})
	w.SetPosition(npc, &PositionComp{X: 5, Y: 0, Z: 0})

	// player2 at (10, 0, 0) — within 50 m and must be included.
	p2 := w.NewEntity()
	w.SetPlayer(p2, &PlayerComp{GatewaySeqID: 11})
	w.SetPosition(p2, &PositionComp{X: 10, Y: 0, Z: 0})

	nearby := w.GetNearbyPlayers(p1, 50)

	if len(nearby) != 1 {
		t.Fatalf("expected exactly 1 nearby player, got %d: %v", len(nearby), nearby)
	}
	if nearby[0] != p2 {
		t.Errorf("expected nearby[0]==%v (player2), got %v", p2, nearby[0])
	}
}

// TestGetNearbyPlayers_ExcludesSelf verifies that the querying entity itself
// is never included in the returned slice.
func TestGetNearbyPlayers_ExcludesSelf(t *testing.T) {
	w := NewWorld()

	p1 := w.NewEntity()
	w.SetPlayer(p1, &PlayerComp{GatewaySeqID: 20})
	w.SetPosition(p1, &PositionComp{X: 0, Y: 0, Z: 0})

	p2 := w.NewEntity()
	w.SetPlayer(p2, &PlayerComp{GatewaySeqID: 21})
	w.SetPosition(p2, &PositionComp{X: 5, Y: 0, Z: 0})

	nearby := w.GetNearbyPlayers(p1, 50)

	for _, id := range nearby {
		if id == p1 {
			t.Error("GetNearbyPlayers must not include the querying entity itself")
		}
	}
	// Sanity: p2 must be there.
	found := false
	for _, id := range nearby {
		if id == p2 {
			found = true
		}
	}
	if !found {
		t.Errorf("expected player2 (%v) in nearby list, got %v", p2, nearby)
	}
}

// TestDestroyEntity_ClearsCharName verifies that after DestroyEntity the
// destroyed player's CharName can no longer be found.
func TestDestroyEntity_ClearsCharName(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()
	w.SetPlayer(e, &PlayerComp{GatewaySeqID: 30, CharName: "Zeta"})

	// Confirm found before destroy.
	if _, ok := w.FindPlayerByName("Zeta"); !ok {
		t.Fatal("expected to find 'Zeta' before DestroyEntity")
	}

	w.DestroyEntity(e)

	if _, ok := w.FindPlayerByName("Zeta"); ok {
		t.Error("expected FindPlayerByName to return false after DestroyEntity")
	}
}
