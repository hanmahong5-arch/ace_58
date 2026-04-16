package ecs

import (
	"testing"
)

// TestAddBuff_Basic verifies that a single buff is stored correctly.
func TestAddBuff_Basic(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()

	w.AddBuff(e, &BuffEntry{BuffID: 1, ExpiresAtTick: 100})

	buffs := w.GetBuffs(e)
	if len(buffs) != 1 {
		t.Fatalf("expected 1 buff, got %d", len(buffs))
	}
	if buffs[0].BuffID != 1 {
		t.Errorf("expected BuffID=1, got %d", buffs[0].BuffID)
	}
}

// TestAddBuff_Refresh verifies that re-adding the same BuffID replaces the entry
// and the resulting slice length stays at 1.
func TestAddBuff_Refresh(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()

	w.AddBuff(e, &BuffEntry{BuffID: 1, ExpiresAtTick: 50})
	w.AddBuff(e, &BuffEntry{BuffID: 1, ExpiresAtTick: 200})

	buffs := w.GetBuffs(e)
	if len(buffs) != 1 {
		t.Fatalf("expected 1 buff after refresh, got %d", len(buffs))
	}
	if buffs[0].ExpiresAtTick != 200 {
		t.Errorf("expected refreshed ExpiresAtTick=200, got %d", buffs[0].ExpiresAtTick)
	}
}

// TestGetBuffs_Snapshot verifies that GetBuffs returns a copy; mutating the
// returned slice must not affect the world's internal state.
func TestGetBuffs_Snapshot(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()

	w.AddBuff(e, &BuffEntry{BuffID: 10, ExpiresAtTick: 300})

	snapshot := w.GetBuffs(e)
	if len(snapshot) != 1 {
		t.Fatalf("expected 1 buff, got %d", len(snapshot))
	}

	// Modify the returned slice and pointer to make sure the internal store is untouched.
	snapshot[0] = &BuffEntry{BuffID: 99, ExpiresAtTick: 1}
	snapshot = snapshot[:0]

	after := w.GetBuffs(e)
	if len(after) != 1 {
		t.Fatalf("internal state was mutated: expected 1 buff, got %d", len(after))
	}
	if after[0].BuffID != 10 {
		t.Errorf("internal state was mutated: expected BuffID=10, got %d", after[0].BuffID)
	}
}

// TestRemoveExpiredBuffs_OnlyExpired verifies that only the expired buff is
// removed (expires=50 at tick=100) while the non-expired one (expires=200) remains.
func TestRemoveExpiredBuffs_OnlyExpired(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()

	w.AddBuff(e, &BuffEntry{BuffID: 1, ExpiresAtTick: 50})
	w.AddBuff(e, &BuffEntry{BuffID: 2, ExpiresAtTick: 200})

	removed := w.RemoveExpiredBuffs(e, 100)

	if len(removed) != 1 {
		t.Fatalf("expected 1 expired buff, got %d", len(removed))
	}
	if removed[0].BuffID != 1 {
		t.Errorf("expected removed BuffID=1, got %d", removed[0].BuffID)
	}

	remaining := w.GetBuffs(e)
	if len(remaining) != 1 {
		t.Fatalf("expected 1 remaining buff, got %d", len(remaining))
	}
	if remaining[0].BuffID != 2 {
		t.Errorf("expected remaining BuffID=2, got %d", remaining[0].BuffID)
	}
}

// TestRemoveExpiredBuffs_DoT verifies that a DoT entry (IsDot=true) is properly
// removed when its expiry tick has passed.
func TestRemoveExpiredBuffs_DoT(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()

	w.AddBuff(e, &BuffEntry{
		BuffID:        -1,
		IsDot:         true,
		DamagePerTick: 50,
		Element:       "fire",
		ExpiresAtTick: 30,
	})

	removed := w.RemoveExpiredBuffs(e, 100)

	if len(removed) != 1 {
		t.Fatalf("expected 1 removed DoT, got %d", len(removed))
	}
	if !removed[0].IsDot {
		t.Error("removed entry should have IsDot=true")
	}
	if removed[0].DamagePerTick != 50 {
		t.Errorf("expected DamagePerTick=50, got %f", removed[0].DamagePerTick)
	}

	remaining := w.GetBuffs(e)
	if len(remaining) != 0 {
		t.Fatalf("expected 0 remaining buffs, got %d", len(remaining))
	}
}

// TestDestroyEntity_ClearsBuffs verifies that DestroyEntity removes all
// buff state so GetBuffs returns nil or empty.
func TestDestroyEntity_ClearsBuffs(t *testing.T) {
	w := NewWorld()
	e := w.NewEntity()

	w.AddBuff(e, &BuffEntry{BuffID: 5, ExpiresAtTick: 999})
	w.DestroyEntity(e)

	buffs := w.GetBuffs(e)
	if len(buffs) != 0 {
		t.Errorf("expected 0 buffs after DestroyEntity, got %d", len(buffs))
	}
}
