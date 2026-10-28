# COMM-1 source-lock contention follow-up

- Status: Scoped fence implemented; subsequent ADR 0054 completes the bounded local source prerequisite
- Date: 2026-10-25
- Owner: People and platform engineering; François retains the implementation decision
- Trigger: the composed source candidate exceeded the retained classroom p95-impact limit
- Evidence: [source checkpoint](../phase-2/staff-audience-source-evidence.md)

## Concrete decision

François authorized this follow-up on 2026-10-25. [ADR 0053](../adr/0053-people-owned-source-write-fence.md)
and its [executed checkpoint](../phase-2/people-source-write-fence-evidence.md) record the new
write fence, before/after blocking observations, tests and migration trials. The unchanged
foundation workload passed all three repeats. At that checkpoint, actual attendance rejected
operations even in baseline at the existing six-slot limit, and qualification correctly stopped.
François subsequently asked to address that blocker. The separately scoped
[ADR 0054 successor](../phase-2/same-writer-admission-evidence.md) implements exact-writer permit
reuse, passes both unchanged workloads in six comparisons each, and completes specialist/full
verification. That result qualifies only the recorded local source prerequisite; publication
remains unimplemented. The original failed results below remain historical evidence.

The original recommendation was to identify the classroom-conflicting source locks and qualify
a People-owned write-boundary fence if that was the measured cause.
Preserve the 25-person cap, source traversal caps, two-second deadline, complete frozen basis,
READ COMMITTED contract and classroom p95-impact limit of 20%.

## Evidence and limits

The first measured six-client run used four classroom readers, one real classroom writer and
one source reader against the same fixture and six-slot admission configuration. Five captures
each resolved 25 intended people. All operations completed and absolute latencies were below
their targets, but all three repeats failed the classroom-impact criterion. These are application
call timings on a shared development machine, not selected-deployment capacity evidence.

The candidate holds participation, person, association, membership and reachable authority parents,
plus the institution and module/account fences. Existing classroom writers also acquire People
participation and institution locks. This establishes a plausible contention path, not a measured
attribution of every millisecond. A blanket new service, increased pool/capacity limit or relaxed
latency threshold would not resolve the required source-consistency proof.

## Recommended bounded work

1. Repeat the unchanged baseline/mixed harness with bounded PostgreSQL lock-wait observations
   and source-stage timings, including the real attendance read/write journey as well as the
   foundation writer. Retain only aggregate timing/blocking evidence, no identities or source rows.
2. If People row/parent locks are the demonstrated bottleneck, propose a small extension to the
   existing People database guard that participates in its existing tenant-qualified lifecycle
   fence on every relevant INSERT/UPDATE/DELETE. Named writers already use that key; alternate
   writes must not bypass it. Exact trigger order, foreign-key waits, deadlocks and rollback need
   their own proof before changing the reader.
3. Only after the write boundary is proven, qualify replacing redundant reader row locks with
   that owner-controlled fence and the minimal institution lock needed for status/time-zone
   stability. Preserve membership, role/grant and account correctness; do not infer that their
   independent locks can also be removed.
4. Repeat all recipient/denial/race/time/deadline/bound tests and at least three unchanged-load
   classroom comparisons. Add direct-write bypass and reverse-order writer tests. Stop if the
   fix needs a wider authority/session contract or still misses the retained limit.
5. Obtain the four specialist dispositions and the engineering checks permitted for that increment
   before returning to publication planning. Independent assurance and release remain separate.

## Alternatives

- Keep the current candidate private and not qualified. This preserves correctness evidence but
  leaves publication unavailable; it is the current disposition.
- Shorten/optimize source queries only. This may reduce elapsed time but does not remove a conflicting
  lock boundary; measure it rather than promise that batching alone meets the target.
- Increase concurrency limits, weaken the fence, truncate the audience, accept stale preparation,
  or relax the 20% limit. Excluded by the existing proof contract.

## Authorization boundary

The implemented write fence changes a People write-boundary contract beyond the original source-reader
composition. François supplied the required authorization and ADR 0053 preceded implementation under the
[original stop condition](communications-comm-1-staff-announcement-proposal.md#authoritative-source-preparation-and-publication).
The authorization covers only that fence, its tests/impact trials and agent review. A wider admission,
authority or session change needs its own scoped decision. No audience generation mechanism,
production scheduler, publication path, new module, public route, real data or release is added.
