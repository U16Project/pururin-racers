"""M5 の決定的なサーバー権威レース処理。"""

from __future__ import annotations

import json
from pathlib import Path
from dataclasses import dataclass, field
from typing import Any

RACERS = 8
TICK_RATE = 20
COURSE_LAYOUT_PATH = Path(__file__).resolve().parents[1] / "shared" / "course_layout_m5.json"
with COURSE_LAYOUT_PATH.open(encoding="utf-8") as layout_file:
    COURSE_LAYOUT = json.load(layout_file)
COURSE_ID = str(COURSE_LAYOUT["course_id"])
TRACK_LENGTH_M = float(COURSE_LAYOUT["track_length_m"])
STRAIGHT_LEN_M = float(COURSE_LAYOUT["straight_length_m"])
TURN_RADIUS_M = float(COURSE_LAYOUT["turn_radius_m"])
GOAL_PATH_M = float(COURSE_LAYOUT["goal_path_m"])
RACE_DISTANCE_M = 2000.0
ROUTES = {
    float(route["distance_m"]): route for route in COURSE_LAYOUT["routes"]
}
GEOMETRIC_BLEND = 0.85
MIN_DISTANCE_MULT = 0.05
LANE_MIN = -6.0
LANE_MAX = 6.0
CONTACT_LONGITUDINAL_M = 1.5
CONTACT_LATERAL_M = 1.5
MAX_DRAFT_RECEIVED_P = 0.24
DRAFT_ASSIST_MAX_KMH = 4.0
MAX_DRAFT_SOURCES = 3
MAX_DRAFT_FORWARD_M = 8.0
MAX_DRAFT_LINE_M = 1.8
CHAIN_DRAFT_ATTENUATION = 0.25
MAX_CHAIN_DRAFT_P = MAX_DRAFT_RECEIVED_P * 0.25


def route_for_distance(distance_m: float) -> dict[str, Any]:
    return ROUTES[float(distance_m)]


def route_mainline_distance(route: dict[str, Any], route_distance: float) -> float:
    start = float(route["start_mainline_m"])
    remaining = max(0.0, route_distance)
    for segment in route["segments"]:
        length = float(segment["distance_m"])
        consumed = min(remaining, length)
        if segment["type"] == "mainline":
            return (start + consumed) % TRACK_LENGTH_M
        # The 160 m launch segment is a dedicated straight before mainline 0.
        remaining -= consumed
        if remaining <= 0.0:
            return (start - (length - consumed)) % TRACK_LENGTH_M
    return (start + route_distance) % TRACK_LENGTH_M


def curvature_at(distance: float, route: dict[str, Any] | None = None) -> float:
    """中心線の曲率(1/m)。スタジアムの直線は0、半円ターンは1/R。"""
    if route is not None:
        if route["segments"][0]["type"] == "straight" and distance < float(
            route["segments"][0]["distance_m"]
        ):
            return 0.0
        distance = route_mainline_distance(route, distance)
    arc_length = (TRACK_LENGTH_M - 2.0 * STRAIGHT_LEN_M) / 2.0
    position = distance % TRACK_LENGTH_M
    if position < STRAIGHT_LEN_M:
        return 0.0
    if position < STRAIGHT_LEN_M + arc_length:
        return 1.0 / TURN_RADIUS_M
    if position < STRAIGHT_LEN_M + arc_length + STRAIGHT_LEN_M:
        return 0.0
    return 1.0 / TURN_RADIUS_M


def distance_multiplier(offset: float, curvature: float = 0.0) -> float:
    """必要中心線距離の倍率。offsetは負が内側、正が外側。"""
    geometric = 1.0 + offset * curvature
    blended = 1.0 + (geometric - 1.0) * GEOMETRIC_BLEND
    return max(MIN_DISTANCE_MULT, blended)


def centerline_delta_from_kmh(
    speed_kmh: float, delta: float, offset: float, curvature: float
) -> float:
    """対地速度(km/h)から確定中心線進行(m)を求める。"""
    return max(0.0, speed_kmh / 3.6 * delta / distance_multiplier(offset, curvature))


def _own_wake_from_speed(speed: float) -> float:
    return min(0.18, 0.06 + max(0.0, speed) / 75.0 * 0.12)


@dataclass
class RacerState:
    racer_id: str
    name: str
    cpu: bool
    max_speed: float
    acceleration: float
    distance: float = 0.0
    race_progress: float = 0.0
    offset: float = 0.0
    # speed は接触解決前の計画／追従速度。確定進行の実測値ではない。
    speed: float = 52.0
    # actual_speed_kmh は接触解決後に確定した進行量から算出する実測速度。
    actual_speed_kmh: float = 0.0
    target_speed: float = 58.0
    target_offset: float = 0.0
    cpu_base_speed: float = 0.0
    own_wake_p: float = 0.0
    direct_draft_p: float = 0.0
    chain_draft_p: float = 0.0
    received_draft_p: float = 0.0
    direct_source_ids: list[str] = field(default_factory=list)
    chain_source_ids: list[str] = field(default_factory=list)
    draft_source_ids: list[str] = field(default_factory=list)
    primary_source_id: str = ""
    primary_gap_m: float = 0.0
    primary_line_gap_m: float = 0.0
    draft_distance_m: float = 0.0
    draft_line_gap_m: float = 0.0
    direct_source_details: list[dict[str, Any]] = field(default_factory=list)
    contact: bool = False
    finished: bool = False
    finish_order: int = 0
    finish_time: float = -1.0

    def snapshot(self) -> dict[str, Any]:
        return {
            "id": self.racer_id,
            "name": self.name,
            "cpu": self.cpu,
            "distance": round(self.distance, 4),
            "race_progress": round(self.race_progress, 4),
            "offset": round(self.offset, 4),
            "speed": round(self.speed, 4),
            "actual_speed_kmh": round(self.actual_speed_kmh, 4),
            "target_speed": round(self.target_speed, 4),
            "own_wake_p": round(self.own_wake_p, 6),
            "direct_draft_p": round(self.direct_draft_p, 6),
            "chain_draft_p": round(self.chain_draft_p, 6),
            "received_draft_p": round(self.received_draft_p, 6),
            "direct_source_ids": list(self.direct_source_ids),
            "chain_source_ids": list(self.chain_source_ids),
            "draft_source_ids": list(self.draft_source_ids),
            "primary_source_id": self.primary_source_id,
            "primary_gap_m": round(self.primary_gap_m, 4),
            "primary_line_gap_m": round(self.primary_line_gap_m, 4),
            "draft_distance_m": round(self.draft_distance_m, 4),
            "draft_line_gap_m": round(self.draft_line_gap_m, 4),
            "direct_source_details": [
                {
                    "id": detail["id"],
                    "gap": round(detail["gap"], 4),
                    "line": round(detail["line"], 4),
                    "contribution_p": round(detail["contribution_p"], 6),
                }
                for detail in self.direct_source_details
            ],
            "contact": self.contact,
            "finished": self.finished,
            "finish_order": self.finish_order,
            "finish_time": round(self.finish_time, 4),
        }


def _forward_gap(progress: float, other_progress: float) -> float:
    """Race progress は単調増加なので、閉路 distance を前後判定に使わない。"""
    return other_progress - progress


def _calculate_draft_details(
    snapshot: list[dict[str, Any]], index: int
) -> tuple[
    float,
    float,
    float,
    list[dict[str, float | str]],
    list[str],
]:
    """前tickの連鎖値を使い、同tickの更新値は参照しない。"""
    receiver = snapshot[index]
    own_wake = _own_wake_from_speed(float(receiver.get("speed", 0.0)))
    if bool(receiver.get("finished", False)):
        return own_wake, 0.0, 0.0, [], []
    sources: list[tuple[float, float, float, str, int]] = []
    for source_index, source in enumerate(snapshot):
        if source_index == index:
            continue
        gap = _forward_gap(receiver["race_progress"], source["race_progress"])
        line_gap = abs(receiver["offset"] - source["offset"])
        if (
            not bool(source.get("finished", False))
            and 0.0 < gap <= MAX_DRAFT_FORWARD_M
            and line_gap <= MAX_DRAFT_LINE_M
        ):
            distance_falloff = 1.0 - gap / MAX_DRAFT_FORWARD_M
            line_falloff = 1.0 - line_gap / MAX_DRAFT_LINE_M
            source_own_wake = float(source.get("own_wake_p", 0.0))
            if source_own_wake <= 0.0:
                source_own_wake = _own_wake_from_speed(float(source.get("speed", 0.0)))
            source_own_wake = min(0.18, max(0.0, source_own_wake))
            direct_strength = max(
                0.0, source_own_wake * distance_falloff * line_falloff
            )
            sources.append(
                (
                    gap,
                    line_gap,
                    direct_strength,
                    str(source.get("id", source_index)),
                    source_index,
                )
            )
    sources.sort(key=lambda item: (item[0], item[3]))
    selected = [source for source in sources if source[2] > 0.0][:MAX_DRAFT_SOURCES]
    if not selected:
        return own_wake, 0.0, 0.0, [], []
    direct_raw = sum(item[2] for item in selected)
    direct = min(MAX_DRAFT_RECEIVED_P, direct_raw)
    direct_scale = direct / direct_raw if direct_raw > 0.0 else 0.0
    source_details = [
        {
            "id": source_id,
            "gap": gap,
            "line": line_gap,
            "contribution_p": strength * direct_scale,
        }
        for gap, line_gap, strength, source_id, _source_index in selected
    ]
    chain_sources: list[str] = []
    chain_strengths: list[float] = []
    for gap, line_gap, _direct_strength, source_id, source_index in selected:
        source = snapshot[source_index]
        source_previous_draft = min(
            MAX_DRAFT_RECEIVED_P,
            max(
                0.0,
                float(source.get("direct_draft_p", 0.0))
                + float(source.get("chain_draft_p", 0.0)),
            ),
        )
        chain_strength = (
            source_previous_draft
            * CHAIN_DRAFT_ATTENUATION
            * (1.0 - gap / MAX_DRAFT_FORWARD_M)
            * (1.0 - line_gap / MAX_DRAFT_LINE_M)
        )
        if chain_strength > 0.0:
            chain_sources.append(source_id)
            chain_strengths.append(chain_strength)
    chain = min(MAX_CHAIN_DRAFT_P, sum(chain_strengths))
    return own_wake, direct, chain, source_details, chain_sources


def calculate_draft(snapshot: list[dict[str, Any]], index: int) -> tuple[float, float]:
    own_wake, direct, chain, _sources, _chain_sources = _calculate_draft_details(
        snapshot, index
    )
    return own_wake, direct + chain


def _apply_draft_details(
    racer: RacerState,
    details: tuple[float, float, float, list[tuple[str, float, float]], list[str]],
) -> None:
    own_wake, direct, chain, sources, chain_sources = details
    racer.own_wake_p = own_wake
    racer.direct_draft_p = direct
    racer.chain_draft_p = chain
    racer.received_draft_p = direct + chain
    racer.direct_source_ids = [str(detail["id"]) for detail in sources]
    racer.chain_source_ids = chain_sources
    racer.draft_source_ids = [str(detail["id"]) for detail in sources]
    if sources:
        racer.primary_source_id = str(sources[0]["id"])
        racer.primary_gap_m = float(sources[0]["gap"])
        racer.primary_line_gap_m = float(sources[0]["line"])
        racer.draft_distance_m = racer.primary_gap_m
        racer.draft_line_gap_m = racer.primary_line_gap_m
    else:
        racer.primary_source_id = ""
        racer.primary_gap_m = 0.0
        racer.primary_line_gap_m = 0.0
        racer.draft_distance_m = 0.0
        racer.draft_line_gap_m = 0.0
    racer.direct_source_details = sources


class M5Race:
    """入力を受け、8頭の状態を決定し、配信用 tick を返す。"""

    def __init__(
        self,
        race_id: str = "m5-local",
        seed: int = 0,
        distance_m: float = RACE_DISTANCE_M,
    ) -> None:
        self.race_id = race_id
        self.seed = seed
        self.route = route_for_distance(distance_m)
        self.route_id = str(self.route["route_id"])
        self.distance_m = float(self.route["distance_m"])
        self.started = False
        self.finished = False
        self.tick_number = 0
        self.finish_count = 0
        self.racers: list[RacerState] = []
        self.inputs: dict[str, dict[str, float]] = {}
        self._tick_start_progress: dict[str, float] = {}

    def start(self, player_id: str = "player-1") -> dict[str, Any]:
        if self.started:
            return self.start_payload(player_id)
        self.started = True
        profiles = [
            (player_id, "あなた", False, 75.0, 14.0, 58.0, -3.0, 0.0),
            ("cpu-1", "CPU・先頭型", True, 72.0, 12.0, 62.0, -1.5, 62.0),
            ("cpu-2", "CPU・内側型", True, 70.0, 11.0, 56.0, -4.5, 56.0),
            ("cpu-3", "CPU・集団型", True, 69.0, 10.0, 58.0, 0.0, 58.0),
            ("cpu-4", "CPU・外側型", True, 76.0, 13.0, 60.0, 4.5, 60.0),
            ("cpu-5", "CPU・差し型", True, 73.0, 11.0, 59.0, 1.5, 59.0),
            ("cpu-6", "CPU・追込型", True, 78.0, 12.0, 57.0, 3.0, 57.0),
            ("cpu-7", "CPU・安定型", True, 71.0, 10.0, 61.0, -0.5, 61.0),
        ]
        start_mainline = float(self.route["start_mainline_m"])
        self.racers = [
            RacerState(
                rid, name, cpu, cap, accel, distance=start_mainline,
                target_speed=target,
                offset=offset, target_offset=offset, speed=target - 6.0,
                cpu_base_speed=cpu_base_speed,
            )
            for rid, name, cpu, cap, accel, target, offset, cpu_base_speed in profiles
        ]
        return self.start_payload(player_id)

    def start_payload(self, player_id: str) -> dict[str, Any]:
        return {
            "v": 1, "t": "race_start", "race_id": self.race_id,
            "course_id": COURSE_ID, "route_id": self.route_id,
            "goal_path_m": GOAL_PATH_M, "distance_m": self.distance_m,
            "tick_rate": TICK_RATE, "elapsed_seconds": 0.0,
            "racers": [r.snapshot() for r in self.racers],
        }

    def receive_input(self, player_id: str, payload: dict[str, Any]) -> None:
        if not self.started or self.finished or player_id != self.racers[0].racer_id:
            return
        self.inputs[player_id] = {
            "target_speed": float(payload.get("target_speed", self.racers[0].target_speed)),
            "target_offset": float(payload.get("target_offset", self.racers[0].target_offset)),
        }

    def tick(self, delta: float = 1.0 / TICK_RATE) -> dict[str, Any]:
        if not self.started:
            raise RuntimeError("race has not started")
        if self.finished:
            for racer in self.racers:
                racer.actual_speed_kmh = 0.0
            return self.tick_payload()
        # Phase 1: tick 開始時点だけを読む。ドラフト補助は前 tick に確定した
        # received 値であり、同 tick の更新順には依存させない。
        snapshot = [r.snapshot() for r in self.racers]
        self._tick_start_progress = {
            racer.racer_id: racer.race_progress for racer in self.racers
        }
        tick_start_distances = {
            racer.racer_id: racer.distance for racer in self.racers
        }
        player_input = self.inputs.get(self.racers[0].racer_id, {})
        player = self.racers[0]
        player.target_speed = max(45.0, min(player.max_speed, player_input.get("target_speed", player.target_speed)))
        player.target_offset = max(LANE_MIN, min(LANE_MAX, player_input.get("target_offset", player.target_offset)))
        plans: list[dict[str, float]] = []
        for index, racer in enumerate(self.racers):
            if racer.finished:
                plans.append({
                    "speed": racer.speed,
                    "target_speed": racer.target_speed,
                    "offset": racer.offset,
                    "advance": 0.0,
                    "progress": racer.race_progress,
                })
                continue
            if racer.cpu:
                racer.target_speed = self._cpu_target_speed(racer, index)
                racer.target_offset = max(LANE_MIN, min(LANE_MAX, racer.target_offset))
            # 前 tick の received は、直接＋連鎖を既に上限内で確定した値。
            received_draft = min(
                MAX_DRAFT_RECEIVED_P,
                max(0.0, float(snapshot[index].get("received_draft_p", 0.0))),
            )
            assist_speed = DRAFT_ASSIST_MAX_KMH * (
                received_draft / MAX_DRAFT_RECEIVED_P
            )
            effective_target = min(racer.max_speed, racer.target_speed + assist_speed)
            speed = racer.speed + max(
                -racer.acceleration,
                min(racer.acceleration, effective_target - racer.speed),
            ) * delta
            offset = racer.offset + max(
                -3.0 * delta,
                min(3.0 * delta, racer.target_offset - racer.offset),
            )
            curvature = curvature_at(racer.race_progress, self.route)
            advance = centerline_delta_from_kmh(
                speed, delta, offset, curvature
            )
            plans.append({
                "speed": speed,
                "target_speed": racer.target_speed,
                "offset": offset,
                "advance": advance,
                "progress": racer.race_progress + advance,
            })

        # Phase 2: 開始時の前後・横差を基準に、前方から決定的に接触を解決する。
        # 後続は同 tick に既に進んだ距離より後退しない。
        resolved_progress = self._resolve_contacts(snapshot, plans)
        for index, racer in enumerate(self.racers):
            plan = plans[index]
            racer.speed = plan["speed"]
            racer.target_speed = plan["target_speed"]
            racer.offset = plan["offset"]
            racer.race_progress = resolved_progress[index]
            progress_delta = max(
                0.0,
                racer.race_progress - self._tick_start_progress[racer.racer_id],
            )
            racer.actual_speed_kmh = (
                progress_delta / delta * 3.6 if delta > 0.0 else 0.0
            )
            racer.distance = route_mainline_distance(
                self.route, racer.race_progress
            )
        self.tick_number += 1
        self._mark_finishes()

        # Phase 3: 移動後の状態から direct を全員同時に算出する。chain は direct
        # source が前 tick に受けた値だけを弱く引き継ぎ、同 tick の値を読まない。
        post_move_snapshot = [r.snapshot() for r in self.racers]
        for index, racer in enumerate(self.racers):
            _apply_draft_details(
                racer, _calculate_draft_details(post_move_snapshot, index)
            )
        return self.tick_payload()

    def _cpu_target_speed(self, racer: RacerState, index: int) -> float:
        """M5 仮 AI: 固定基準速度に、再現可能な小さな局面変化だけを加える。"""
        phase = ((self.tick_number // 80 + index * 3) % 5 - 2) * 0.2
        return max(45.0, min(racer.max_speed, racer.cpu_base_speed + phase))

    def _resolve_contacts(
        self, snapshot: list[dict[str, Any]], plans: list[dict[str, float]]
    ) -> list[float]:
        resolved = [plan["progress"] for plan in plans]
        for racer in self.racers:
            racer.contact = False
        order = sorted(
            range(len(self.racers)),
            key=lambda index: (-float(snapshot[index]["race_progress"]), self.racers[index].racer_id),
        )
        for leader_index in order:
            leader = self.racers[leader_index]
            if leader.finished:
                continue
            leader_start = float(snapshot[leader_index]["race_progress"])
            for follower_index in order:
                if follower_index == leader_index:
                    continue
                follower = self.racers[follower_index]
                if follower.finished:
                    continue
                follower_start = float(snapshot[follower_index]["race_progress"])
                if (
                    follower_start >= leader_start
                    or abs(float(snapshot[follower_index]["offset"]) - float(snapshot[leader_index]["offset"])) >= CONTACT_LATERAL_M
                    or resolved[follower_index] < resolved[leader_index] - CONTACT_LONGITUDINAL_M
                ):
                    continue
                leader.contact = True
                follower.contact = True
                # tick 開始時の生 float を下限にし、接触でも後退させない。
                resolved[follower_index] = max(
                    self._tick_start_progress[follower.racer_id],
                    min(
                        resolved[follower_index],
                        resolved[leader_index] - CONTACT_LONGITUDINAL_M,
                    ),
                )
        return resolved

    def _mark_finishes(self) -> None:
        crossing = [
            racer for racer in self.racers
            if not racer.finished and racer.race_progress >= self.distance_m
        ]
        crossing_times = []
        tick_start = (self.tick_number - 1) / TICK_RATE
        for racer in crossing:
            start_progress = self._tick_start_progress.get(
                racer.racer_id, racer.race_progress
            )
            progress_delta = racer.race_progress - start_progress
            fraction = (
                (RACE_DISTANCE_M - start_progress) / progress_delta
                if progress_delta > 0.0
                else 1.0
            )
            crossing_times.append(
                (tick_start + max(0.0, min(1.0, fraction)) / TICK_RATE, racer)
            )
        crossing_times.sort(key=lambda item: (item[0], item[1].racer_id))
        for finish_time, racer in crossing_times:
            self.finish_count += 1
            racer.finished = True
            racer.finish_order = self.finish_count
            racer.finish_time = finish_time
            racer.speed = 0.0
            racer.target_speed = 0.0
            racer.direct_draft_p = 0.0
            racer.chain_draft_p = 0.0
            racer.received_draft_p = 0.0
            racer.direct_source_ids = []
            racer.chain_source_ids = []
            racer.draft_source_ids = []
            racer.direct_source_details = []
            racer.primary_source_id = ""
            racer.primary_gap_m = 0.0
            racer.primary_line_gap_m = 0.0
            racer.draft_distance_m = 0.0
            racer.draft_line_gap_m = 0.0
        self.finished = self.finish_count == len(self.racers)

    def tick_payload(self) -> dict[str, Any]:
        return {
            "v": 1, "t": "race_tick", "race_id": self.race_id,
            "course_id": COURSE_ID, "route_id": self.route_id,
            "distance_m": self.distance_m,
            "tick": self.tick_number,
            "elapsed_seconds": self.tick_number / TICK_RATE,
            "racers": [r.snapshot() for r in self.racers],
        }

    def result_payload(self) -> dict[str, Any]:
        ordered = sorted(
            self.racers,
            key=lambda racer: (racer.finish_time, racer.finish_order, racer.racer_id),
        )
        return {
            "v": 1, "t": "race_result", "race_id": self.race_id,
            "course_id": COURSE_ID, "route_id": self.route_id,
            "distance_m": self.distance_m,
            "elapsed_seconds": self.tick_number / TICK_RATE,
            "results": [{
                            "id": r.racer_id,
                            "rank": i + 1,
                            "race_progress": r.race_progress,
                            "finish_order": r.finish_order,
                            "finish_time": r.finish_time,
                            "time": r.finish_time,
                        }
                        for i, r in enumerate(ordered)],
        }
