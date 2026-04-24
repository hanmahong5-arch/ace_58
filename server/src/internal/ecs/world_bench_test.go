package ecs

import "testing"

// BenchmarkEntityCreate measures how fast new entities can be allocated.
// Entity allocation happens on every player login and NPC spawn.
func BenchmarkEntityCreate(b *testing.B) {
	world := NewWorld()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = world.NewEntity()
	}
}

// BenchmarkSetStat measures a single stat write.
// Called every time a stat changes (hp/mp update on damage, buff apply, etc).
func BenchmarkSetStat(b *testing.B) {
	world := NewWorld()
	e := world.NewEntity()
	// Pre-create the StatsComp so the benchmark measures steady-state writes,
	// not first-write allocation.
	world.SetStat(e, "hp", 1000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		world.SetStat(e, "hp", float64(i))
	}
}

// BenchmarkGetStat measures a single stat read.
// Stat lookups fire on every skill resolution, damage calc, and tick update.
func BenchmarkGetStat(b *testing.B) {
	world := NewWorld()
	e := world.NewEntity()
	world.SetStat(e, "hp", 1000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = world.GetStat(e, "hp")
	}
}
