# Full planning-horizon restore measurement

- Status: Local full-horizon rehearsal passed; managed restore remains required
- Owner: Platform engineering and operations
- Measured: 2026-09-16
- Machine record: [`full-horizon-restore-measurement.json`](../../../spikes/ash-foundation-lab/priv/maintenance/full-horizon-restore-measurement.json)
- Harness: [`measure_phase0_full_horizon_restore.py`](../../../tools/measure_phase0_full_horizon_restore.py)

## Result

The isolated PostgreSQL 18.6 rehearsal loaded the exact accepted attendance planning horizon of 131,200,000 synthetic retained rows. The source relation occupied 11,080,318,976 heap bytes plus 2,946,940,928 index bytes, 14,030,209,024 bytes in total. Loading took 453,991.331 ms at 288,992 rows/second.

The streaming base backup occupied 14,431,718,782 bytes and completed in 12,937.610 ms. After the backup, the runner enabled real WAL archiving, wrote a target marker, captured its LSN, forced a WAL switch, wrote an after-target marker, and forced a second switch. It then materialized a separate restore directory and recovered inclusively to the target LSN.

| Measure | Result | Accepted local gate |
| --- | ---: | ---: |
| Planning-horizon rows | 131,200,000 | 131,200,000 |
| Restore materialization | 8,351.342 ms | Included in RTO |
| Startup and WAL replay | 1,483.821 ms | Included in RTO |
| Total local restore RTO | 9,835.776 ms | <= 14,400,000 ms |
| Integrity mismatches | 0 | 0 |

The restored row count, minimum and maximum IDs, ID sum, tenant sum, and a full payload-hash sum match the source. Heap and index bytes match exactly. The target marker is present, the later marker is absent, and the restore uses an isolated port. PostgreSQL auxiliary free-space or visibility-map pages are intentionally not byte-identity gates because recovery may allocate them differently without changing authoritative data.

## Reproduction

```sh
mise exec -- uv run python tools/measure_phase0_full_horizon_restore.py \
  --retained-rows 131200000 \
  --output spikes/ash-foundation-lab/priv/maintenance/full-horizon-restore-measurement.json
```

The runner refuses any row count other than the accepted full horizon. It prints progress in ten-million-row chunks, uses `fsync=on`, `full_page_writes=on`, `synchronous_commit=on`, WAL archiving, a streaming base backup, and complete-table fingerprints. Temporary clusters and their multi-gigabyte files are removed after success or failure.

## Boundary

This closes the full-row-count local choreography gap and replaces the earlier 1% restore as scale evidence; it does not rewrite that historical artifact. Synthetic row width and index shape do not predict every future domain, correction, audit, history, or file byte. One local host does not prove zone independence. The local RTO excludes provider control-plane queueing, network transfer, lazy storage initialization, endpoint changes, and restoring explicit network, parameter, monitoring, backup, and HA configuration. The same gate must therefore run in the selected non-AWS deployment; the earlier AWS example is [withdrawn](managed-postgresql-topology.md).
