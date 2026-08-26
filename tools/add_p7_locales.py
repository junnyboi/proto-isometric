#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENTRIES = {
    "en": {
        "settlement.work.status.working": "Working",
        "settlement.work.status.carrying": "Output ready",
        "settlement.work.status.resting": "Resting",
        "settlement.work.status.recovering": "Recovering",
        "settlement.work.status.idle": "Idle",
        "settlement.work.output_count": "Output {count}",
        "settlement.work.idle.no_worker": "Idle: no worker assigned",
        "settlement.work.idle.site_unsafe": "Idle: site is outside the safe work zone",
        "settlement.work.idle.settler_unavailable": "Idle: assigned settler is unavailable",
        "settlement.work.idle.settler_recovering": "Idle: assigned settler is recovering",
        "settlement.work.idle.protected_bed_missing": "Idle: protected bed unavailable",
        "settlement.work.idle.no_compatible_source": "Idle: no compatible source in range",
        "settlement.work.idle.local_output_full": "Idle: local output is full",
        "settlement.work.idle.slot_not_extraction": "Idle: assigned slot does not extract",
        "settlement.work.idle.source_exhausted": "Idle: source is exhausted",
        "settlement.work.idle.source_reserved": "Idle: source is reserved elsewhere",
    },
    "zh-CN": {
        "settlement.work.status.working": "工作中",
        "settlement.work.status.carrying": "产出待运",
        "settlement.work.status.resting": "休息中",
        "settlement.work.status.recovering": "康复中",
        "settlement.work.status.idle": "闲置",
        "settlement.work.output_count": "产出 {count}",
        "settlement.work.idle.no_worker": "闲置：未分配工人",
        "settlement.work.idle.site_unsafe": "闲置：工地不在安全工作区内",
        "settlement.work.idle.settler_unavailable": "闲置：已分配居民当前不可工作",
        "settlement.work.idle.settler_recovering": "闲置：已分配居民正在康复",
        "settlement.work.idle.protected_bed_missing": "闲置：没有受保护床位",
        "settlement.work.idle.no_compatible_source": "闲置：范围内没有兼容资源点",
        "settlement.work.idle.local_output_full": "闲置：本地输出已满",
        "settlement.work.idle.slot_not_extraction": "闲置：所分配岗位不负责采集",
        "settlement.work.idle.source_exhausted": "闲置：资源点已枯竭",
        "settlement.work.idle.source_reserved": "闲置：资源点已被其他工地预留",
    },
}

for locale, additions in ENTRIES.items():
    path = ROOT / "data" / "locales" / f"{locale}.json"
    catalog = json.loads(path.read_text(encoding="utf-8"))
    catalog.update(additions)
    path.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"updated {locale}: {len(additions)} P7 keys")
