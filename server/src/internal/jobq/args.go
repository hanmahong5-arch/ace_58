// scripts/src/internal/jobq/args.go
// JobArgs definitions for durable background work handled by river. Each
// struct implements river.JobArgs (`Kind() string`) and serialises to JSON
// via struct tags.
//
// Kinds use the "aion58.<domain>.<verb>" scheme so queue dashboards can
// filter by subsystem without parsing payloads.

package jobq

// MailDeliverArgs enqueues an asynchronous in-game mail delivery, optionally
// with attached items. The mail worker is the canonical example of a
// transactional job: it MUST be inserted in the same pgx.Tx that writes the
// sender's "item removed" row so the two effects commit atomically.
type MailDeliverArgs struct {
	// SenderCharID is the char_id of the player who initiated the mail.
	// 0 is reserved for system mail (GM grants, event rewards, compensations).
	SenderCharID int64 `json:"sender_char_id"`

	// RecipientCharID is the char_id of the recipient. Never zero.
	RecipientCharID int64 `json:"recipient_char_id"`

	// Subject is the UTF-8 mail subject line (≤ 80 chars by NCSoft convention).
	Subject string `json:"subject"`

	// Body is the UTF-8 mail body (≤ 1024 chars).
	Body string `json:"body"`

	// AttachedItemID is 0 when the mail carries no item; otherwise it is the
	// item template ID to grant on the recipient's read-and-claim action.
	AttachedItemID int32 `json:"attached_item_id"`

	// AttachedItemCount is the stack count for the attached item; 0 or 1 for
	// unstackable gear.
	AttachedItemCount int32 `json:"attached_item_count"`

	// AttachedKinah is the amount of kinah packed into the mail (0 = none).
	AttachedKinah int64 `json:"attached_kinah"`
}

// Kind satisfies river.JobArgs. The string value is load-bearing across
// deploys; renaming it orphans previously inserted rows.
func (MailDeliverArgs) Kind() string { return "aion58.mail.deliver" }

// LegionInviteExpireArgs replaces the tick-counter expiry used in S-10 with
// a durable, persisted timer. When a player invites another to a legion, the
// handler inserts this job scheduled for invite_ttl in the future. On work,
// the job checks whether the invite is still pending and clears it.
type LegionInviteExpireArgs struct {
	LegionID   int64 `json:"legion_id"`
	InviterEID int64 `json:"inviter_eid"`
	TargetEID  int64 `json:"target_eid"`
}

func (LegionInviteExpireArgs) Kind() string { return "aion58.legion.invite_expire" }
