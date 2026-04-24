package ecs

import "testing"

// TestGettersRoundTrip covers GetPlayer, GetPosition, GetNpc — all readers
// that existing tests bypassed because they wrote via Set* but never read.
func TestGettersRoundTrip(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()

	w.SetPlayer(e, &PlayerComp{GatewaySeqID: 7, CharName: "Ion"})
	w.SetPosition(e, &PositionComp{WorldID: 110, X: 1, Y: 2, Z: 3, Heading: 4})
	w.SetNpc(e, &NpcComp{TemplateID: 9001, Level: 55, AIScript: "patrol"})

	if p, ok := w.GetPlayer(e); !ok || p.CharName != "Ion" {
		t.Errorf("GetPlayer round-trip failed: %+v ok=%v", p, ok)
	}
	if pos, ok := w.GetPosition(e); !ok || pos.X != 1 || pos.Heading != 4 {
		t.Errorf("GetPosition round-trip failed: %+v", pos)
	}
	if n, ok := w.GetNpc(e); !ok || n.TemplateID != 9001 || n.AIScript != "patrol" {
		t.Errorf("GetNpc round-trip failed: %+v", n)
	}

	// Absent lookups must return ok=false without panicking.
	other := w.NewEntity()
	if _, ok := w.GetPlayer(other); ok {
		t.Error("GetPlayer on empty entity should return false")
	}
	if _, ok := w.GetPosition(other); ok {
		t.Error("GetPosition on empty entity should return false")
	}
	if _, ok := w.GetNpc(other); ok {
		t.Error("GetNpc on empty entity should return false")
	}
}

// TestCountReflectsLifecycle pins Count() to entity alloc/destroy pairs.
func TestCountReflectsLifecycle(t *testing.T) {
	w := NewWorld()
	if w.Count() != 0 {
		t.Fatalf("fresh world Count = %d, want 0", w.Count())
	}
	a := w.NewEntity()
	b := w.NewEntity()
	if w.Count() != 2 {
		t.Fatalf("Count after 2 NewEntity = %d, want 2", w.Count())
	}
	w.DestroyEntity(a)
	if w.Count() != 1 {
		t.Fatalf("Count after destroy = %d, want 1", w.Count())
	}
	w.DestroyEntity(b)
	if w.Count() != 0 {
		t.Fatalf("Count after drain = %d, want 0", w.Count())
	}
}

// TestStatsReadWrite covers SetStat / GetStat, including the auto-allocation
// of the underlying StatsComp map and the absent-key branch.
func TestStatsReadWrite(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()

	// Absent entity → (0, false).
	if v, ok := w.GetStat(e, "hp"); v != 0 || ok {
		t.Errorf("GetStat on empty: got (%v, %v)", v, ok)
	}

	w.SetStat(e, "hp", 3200)
	w.SetStat(e, "mp", 1800)

	if v, ok := w.GetStat(e, "hp"); !ok || v != 3200 {
		t.Errorf("GetStat hp = (%v,%v)", v, ok)
	}
	if v, ok := w.GetStat(e, "mp"); !ok || v != 1800 {
		t.Errorf("GetStat mp = (%v,%v)", v, ok)
	}
	// Present comp but missing key.
	if v, ok := w.GetStat(e, "fp"); ok || v != 0 {
		t.Errorf("GetStat missing key: (%v,%v)", v, ok)
	}
}

// TestGetEntityBySeqIDIndex exercises the BySeqID reverse index on set and
// destroy, ensuring the index is maintained.
func TestGetEntityBySeqIDIndex(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()
	w.SetPlayer(e, &PlayerComp{GatewaySeqID: 42})

	if got, ok := w.GetEntityBySeqID(42); !ok || got != e {
		t.Fatalf("lookup hit = (%v,%v), want (%v,true)", got, ok, e)
	}
	if _, ok := w.GetEntityBySeqID(999); ok {
		t.Error("unknown seq should miss")
	}

	w.DestroyEntity(e)
	if _, ok := w.GetEntityBySeqID(42); ok {
		t.Error("seq index should drop on DestroyEntity")
	}
}

// TestAllPlayersAndAllNPCs pins the snapshot accessors used by Lua iterators.
func TestAllPlayersAndAllNPCs(t *testing.T) {
	w := NewWorld()
	p := w.NewEntity()
	w.SetPlayer(p, &PlayerComp{GatewaySeqID: 1})
	n := w.NewEntity()
	w.SetNpc(n, &NpcComp{TemplateID: 10})

	if players := w.AllPlayers(); len(players) != 1 || players[0] != p {
		t.Errorf("AllPlayers = %v", players)
	}
	if npcs := w.AllNPCs(); len(npcs) != 1 || npcs[0] != n {
		t.Errorf("AllNPCs = %v", npcs)
	}
}

// TestGetNearbyAndEdgeCases covers GetNearby including self-exclusion,
// radius boundary, and the no-PositionComp short-circuit.
func TestGetNearbyAndEdgeCases(t *testing.T) {
	w := NewWorld()

	// Entity with no PositionComp → nil result.
	lone := w.NewEntity()
	if got := w.GetNearby(lone, 10); got != nil {
		t.Errorf("GetNearby on entity without position should be nil, got %v", got)
	}

	a := w.NewEntity()
	w.SetPosition(a, &PositionComp{X: 0, Y: 0, Z: 0})
	b := w.NewEntity()
	w.SetPosition(b, &PositionComp{X: 3, Y: 4, Z: 0}) // distance 5
	c := w.NewEntity()
	w.SetPosition(c, &PositionComp{X: 100, Y: 0, Z: 0})

	// radius 5 includes b but not c; self is always excluded.
	near := w.GetNearby(a, 5)
	if len(near) != 1 || near[0] != b {
		t.Errorf("GetNearby(a,5) = %v, want [%v]", near, b)
	}
}

// TestBuffRefreshReplacesInPlace validates the documented "same BuffID
// replaces" contract of AddBuff.
func TestBuffRefreshReplacesInPlace(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()

	w.AddBuff(e, &BuffEntry{BuffID: 101, ExpiresAtTick: 10})
	w.AddBuff(e, &BuffEntry{BuffID: 101, ExpiresAtTick: 50}) // refresh

	bs := w.GetBuffs(e)
	if len(bs) != 1 {
		t.Fatalf("expected refresh → 1 entry, got %d", len(bs))
	}
	if bs[0].ExpiresAtTick != 50 {
		t.Errorf("expected refreshed ExpiresAtTick=50, got %d", bs[0].ExpiresAtTick)
	}
}

// TestRemoveExpiredBuffsNoOpOnEmpty covers the early-return branch when the
// entity has no buff list.
func TestRemoveExpiredBuffsNoOpOnEmpty(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()
	if out := w.RemoveExpiredBuffs(e, 100); out != nil {
		t.Errorf("expected nil for empty list, got %v", out)
	}
}
