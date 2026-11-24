"""Build the 0.5 m land-use audit from export_infill_geometry.gd."""
import argparse
import json
from collections import defaultdict
from itertools import combinations
from pathlib import Path

import numpy as np
from scipy import ndimage

STEP = 0.5
AREA = STEP ** 2
MIN_CELLS = int(25 / AREA)
PETERSBURG = (Path(__file__).resolve().parents[2] / "docs" / "infill-v2")
ZONES = (
    ([(30, 20, 41, 26)], ("GardenMerchantAnnex",),
     "Пристройка между дорожкой к скверу и погрузочным проездом."),
    ([(-88, -30, -76, -20)], (),
     "Зона захватывает мощёный выход с поперечной улицы к Неве. Между проездом и мастерской остаётся короткая полоса у торца."),
    ([(-29, 74, -22.5, 86)], ("PrintworksPassage",),
     "Над хозяйственным проходом устроен трёхэтажный арочный корпус. Световая ширина арки 3,6 м."),
    ([(-26, -20, -17, 7)], ("EastLaneTenement", "EastLaneCorner"),
     "Два существующих смежных корпуса сохраняют линию переулка."),
    ([(-43, 0, -33, 25)], ("LaneRearWing", "WorkshopCourtWing"),
     "Сохранены флигели и южный подход к двору."),
    ([(15, -17, 23, 8)], ("MainStreetNorthWing", "MainStreetSouthWing"),
     "Сохранён мощёный двор между флигелями и подъезд с востока."),
    ([(-77, -15, -60, 18)], ("WesternCornerBackWing", "GrocerStoreWing"),
     "Сохранён поперечный мощёный проезд между дворовыми корпусами."),
    ([(76, 21, 86, 26.5), (76, 45.5, 86, 50)], ("OuterQuayFrontLink", "OuterQuayMerchantLink"),
     "Обе существующие вставки примыкают к торцам по восточной линии набережной."),
    ([(90, -290, 196, 149)], (),
     "Периметры вдоль двух параллельных улиц с поперечными проездами и дворами."),
    ([(-92, -375, 210, -290)], (),
     "Два эшелона кварталов с поперечными переулками."),
    ([(-92, 90, 110, 268)], (),
     "Застройка на суше по обе стороны Новой Голландии, без перекрытия каналов и осевых улиц."),
    ([], (),
     "Фасады и дворовые корпуса на сухопутной стороне. У моста сохранён отступ."),
)


def rect(bounds):
    x1, z1, x2, z2 = bounds
    return [(x1, z1), (x2, z1), (x2, z2), (x1, z2)]


def draw(mask, origin, polygon, value=True):
    points = np.asarray(polygon)
    if len(points) < 3:
        return
    first = np.maximum(0, np.floor((points.min(axis=0) - origin) / STEP).astype(int))
    last = np.minimum(mask.shape[::-1], np.ceil((points.max(axis=0) - origin) / STEP).astype(int))
    x0, z0 = first
    x1, z1 = last
    if x1 <= x0 or z1 <= z0:
        return
    x = origin[0] + STEP * (np.arange(x0, x1) + 0.5)
    z = origin[1] + STEP * (np.arange(z0, z1) + 0.5)
    inside = np.zeros((len(z), len(x)), dtype=bool)
    for (ax, az), (bx, bz) in zip(points, np.roll(points, -1, axis=0)):
        if az != bz:
            inside ^= (((z >= min(az, bz)) & (z < max(az, bz)))[:, None]
                       & (x < (ax + (z - az) * (bx - ax) / (bz - az))[:, None]))
    mask[z0:z1, x0:x1][inside] = value


def components(mask, origin, limit=12):
    labels, count = ndimage.label(mask)
    cells = np.bincount(labels.ravel(), minlength=count + 1)
    objects = ndimage.find_objects(labels)
    candidates = np.flatnonzero(cells[1:] >= MIN_CELLS) + 1
    largest = sorted(candidates, key=lambda idx: (-cells[idx], idx))[:limit]
    return {
        "candidate_count": len(candidates),
        "large_void_count": int(np.count_nonzero(cells[1:] >= 150 / AREA)),
        "largest": [
            {"area_m2": cells[idx].item() * AREA,
             "bounds": [origin[0] + objects[idx - 1][1].start * STEP,
                        origin[1] + objects[idx - 1][0].start * STEP,
                        origin[0] + objects[idx - 1][1].stop * STEP,
                        origin[1] + objects[idx - 1][0].stop * STEP]}
            for idx in largest
        ],
    }


def select(item, areas, names, zone):
    if names:
        return any(name in item["path"].split("/") for name in names)
    if item["kind"] != "background":
        return False
    x, _, z = item["position"]
    if zone == 12:
        return x < -92
    return any(x1 <= x < x2 and z1 <= z < z2 for x1, z1, x2, z2 in areas)


def fmt(item):
    parts = item["path"].split("/")
    name = parts[-2] if item["kind"] in ("facade", "structural_collision") else parts[-1]
    if item["kind"] == "background":
        x, _, z = item["position"]
        name = f"{parts[-2]}/{name} ({x:.2f}, {z:.2f})"
    return {
        "building_name": name,
        "position": [round(v, 3) for v in item["position"]],
        "rotation": round(item["rotation"], 3),
        "footprint": [[round(v, 3) for v in point] for point in item["polygon"]],
        "floors": item["floors"],
    }


def polygon_grid(polygon):
    points = np.asarray(polygon)
    origin = np.floor(points.min(axis=0) / STEP) * STEP
    width, depth = np.ceil((points.max(axis=0) - origin) / STEP).astype(int)
    mask = np.zeros((depth, width), dtype=bool)
    draw(mask, origin, points)
    return origin, mask


def collisions(buildings, reserved, dry, origin):
    polygons = [np.asarray(item["polygon"]) for item in buildings]
    buckets = defaultdict(list)
    road, water = [], []
    for idx, (item, polygon) in enumerate(zip(buildings, polygons)):
        lower, upper = np.floor(np.vstack((polygon.min(axis=0), polygon.max(axis=0))) / 16).astype(int)
        for x in range(lower[0], upper[0] + 1):
            for z in range(lower[1], upper[1] + 1):
                buckets[x, z].append(idx)
        if item["kind"] != "background" and not any(
                name in item["path"] for name in ("GardenMerchantAnnex", "PrintworksPassage", "PalaceRearTenement")):
            continue
        local_origin, mask = polygon_grid(polygon)
        x, z = ((local_origin - origin) / STEP).astype(int)
        view = np.s_[z:z + mask.shape[0], x:x + mask.shape[1]]
        if np.any(mask & reserved[view]):
            road.append(item["path"])
        if np.any(mask & ~dry[view]):
            water.append(item["path"])
    overlap = []
    for i, j in sorted({pair for bucket in buckets.values() for pair in combinations(bucket, 2)}):
        if all(buildings[k]["kind"] != "background" for k in (i, j)):
            continue  # The Godot layout validator checks structural volumes in the playable area.
        a, b = polygons[i], polygons[j]
        if np.any(np.maximum(a.min(axis=0), b.min(axis=0)) >= np.minimum(a.max(axis=0), b.max(axis=0))):
            continue
        edges = np.concatenate((a[1:3] - a[:2], b[1:3] - b[:2]))
        axes = edges[:, ::-1] * [1, -1]
        axes /= np.linalg.norm(axes, axis=1)[:, None]
        pa, pb = a @ axes.T, b @ axes.T
        if np.all(np.minimum(pa.max(axis=0), pb.max(axis=0)) -
                  np.maximum(pa.min(axis=0), pb.min(axis=0)) > 0.12):
            overlap.append([buildings[i]["position"], buildings[j]["position"]])
    return {"background_building_overlap_count": len(overlap), "background_overlaps": overlap,
            "resurfaced_footprint_intersection_count": len(road), "surface_intersections": road,
            "water_overlap_count": len(water), "water_intersections": water}


def frontage_gaps(buildings):
    rows = defaultdict(list)
    for item in buildings:
        if item["kind"] == "background":
            rows[item["path"]].append(np.asarray(item["polygon"]))
    gaps = []
    for name, lots in rows.items():
        axis = lots[0][1] - lots[0][0]
        axis /= np.linalg.norm(axis)
        spans = sorted(((lot @ axis).min(), (lot @ axis).max()) for lot in lots)
        for left, right in zip(spans, spans[1:]):
            if right[0] - left[1] > 3:
                gaps.append({"row": name, "width_m": right[0] - left[1]})
    return gaps


def block_coverage(blocks, occupied, origin, excluded):
    coverages = []
    for block in blocks:
        local_origin, mask = polygon_grid(block["polygon"])
        x, z = ((local_origin - origin) / STEP).astype(int)
        view = np.s_[z:z + mask.shape[0], x:x + mask.shape[1]]
        built = occupied[view] & mask
        coverages.append({"position": block["position"], "area_m2": int(mask.sum()) * AREA,
                          "built_area_m2": int(built.sum()) * AREA,
                          "coverage": round(float(built.sum() / mask.sum()), 3)})
        # These are deliberately bounded perimeter parcels with internal courts and access slots.
        excluded[view] |= mask & ~built
    return coverages


def make_report(geometry):
    origin = (-1250, -1080)
    shape = (int((860 - origin[1]) / STEP), int((845 - origin[0]) / STEP))
    dry, reserved, occupied = (np.zeros(shape, dtype=bool) for _ in range(3))
    # Playable dry land is separated from the canal and New Holland water.
    playable = [(-90, -290, 90, -90), (-90, -90, 48, 90), (62, -90, 90, 90),
                (13, 96, 48, 134)]
    for bounds in geometry["dry_ground"] + playable:
        draw(dry, origin, rect(bounds))
    shore = geometry["west_shore"]
    draw(dry, origin, [(-1250, shore[0][1]), *shore, (-1250, shore[-1][1])])
    for item in geometry["reservations"]:
        draw(reserved, origin, item["polygon"])
    for item in geometry["buildings"]:
        draw(occupied, origin, item["polygon"])
    validation = collisions(geometry["buildings"], reserved, dry, origin)
    coverages = block_coverage(geometry["blocks"], occupied, origin, reserved)
    gaps_along_rows = frontage_gaps(geometry["buildings"])
    empty = dry & ~reserved & ~occupied
    result = {
        "grid_resolution_m": STEP,
        "minimum_candidate_area_m2": 25,
        "large_void_threshold_m2": 150,
        "bounds_order": ["x_min", "z_min", "x_max", "z_max"],
        "scan_bounds": [-1250, -1080, 845, 860],
        "frontage_gap_threshold_m": 3,
        "background_frontage_gaps": gaps_along_rows,
        "validation": validation,
        "background_blocks": {
            "target_coverage": 0.8,
            "mean_weighted_coverage": round(sum(b["built_area_m2"] for b in coverages) /
                                            sum(b["area_m2"] for b in coverages), 3),
            "parcels": coverages,
        },
        "scan_note": "Связные свободные ячейки включают намеренные открытые территории и незастраиваемый дальний фон. Размер компоненты сам по себе не разрешает строительство.",
        "whole_map_open_ground": components(empty, origin),
        "additional_buildings": [
            fmt(item) for item in geometry["buildings"] if "PalaceRearTenement" in item["path"].split("/")
        ],
        "zones": [],
    }
    for zone, (areas, names, note) in enumerate(ZONES, 1):
        buildings = [item for item in geometry["buildings"] if select(item, areas, names, zone)]
        if zone == 12:
            areas = [(-405, -397, -211, 284)]
        gaps = []
        for x1, z1, x2, z2 in areas:
            x0, y0 = (np.asarray((x1, z1)) - origin) / STEP
            x_end, y_end = (np.asarray((x2, z2)) - origin) / STEP
            window = np.s_[int(y0):int(y_end), int(x0):int(x_end)]
            analysis = components(empty[window], (x1, z1), limit=5)
            analysis["search_area"] = [x1, z1, x2, z2]
            analysis["occupied_m2"] = int(occupied[window].sum()) * AREA
            gaps.append(analysis)
        result["zones"].append({
            "zone_id": f"INFILL_{zone:03}",
            "status": ("reserved_passage" if zone == 2 else "existing_verified" if 4 <= zone <= 8 else "built"),
            "buildings": [
                {**fmt(item), "floors": 3 if zone == 3 else item["floors"]}
                for item in buildings
            ],
            "remaining_gaps": gaps,
            "reason_if_skipped": note if zone == 2 else None,
            "review": note,
        })
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("geometry", type=Path)
    parser.add_argument("--output", type=Path, default=PETERSBURG / "report.json")
    args = parser.parse_args()
    result = make_report(json.loads(args.geometry.read_text()))
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
