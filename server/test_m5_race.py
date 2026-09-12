"""M5 レース処理の決定性と二層ドラフト境界のテスト。"""

import json
from pathlib import Path

from race_m5 import (
    DRAFT_ASSIST_MAX_KMH,
    MAX_CHAIN_DRAFT_P,
    MAX_DRAFT_RECEIVED_P,
    M5Race,
    _calculate_draft_details,
    calculate_draft,
    centerline_delta_from_kmh,
    curvature_at,
    distance_multiplier,
    ROUTES,
    TRACK_LENGTH_M,
    STRAIGHT_LEN_M,
    TURN_RADIUS_M,
    route_mainline_distance,
)

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_start_creates_one_player_and_seven_cpu() -> None:
    race = M5Race("test")
    message = race.start("player")
    assert len(message["racers"]) == 8
    assert sum(1 for racer in message["racers"] if racer["cpu"]) == 7
    assert all("actual_speed_kmh" in racer for racer in message["racers"])
    assert message["course_id"] == "m5_standard_oval"
    assert message["route_id"] == "m5_2000"
    assert message["distance_m"] == 2000.0


def test_shared_routes_have_exact_distance_and_1600_launch_breakdown() -> None:
    assert TRACK_LENGTH_M == 2083.1
    assert STRAIGHT_LEN_M == 680.0
    assert TURN_RADIUS_M == 115.085
    assert [route["distance_m"] for route in ROUTES.values()] == [
        1200.0, 1600.0, 2000.0, 2400.0, 3000.0
    ]
    route = ROUTES[1600.0]
    assert [segment["distance_m"] for segment in route["segments"]] == [160.0, 1440.0]
    assert sum(segment["distance_m"] for segment in route["segments"]) == route["distance_m"]
    assert route_mainline_distance(route, 160.0) == route["start_mainline_m"]
    assert route_mainline_distance(route, 1600.0) == 400.0


def test_client_course_copy_matches_shared_wire_definition() -> None:
    with (REPO_ROOT / "shared" / "course_layout_m5.json").open(encoding="utf-8") as shared_file:
        shared_layout = json.load(shared_file)
    with (REPO_ROOT / "client" / "data" / "course_layout_m5.json").open(encoding="utf-8") as client_file:
        client_layout = json.load(client_file)
    assert client_layout == shared_layout


def test_route_goal_is_home_straight_path_400_for_all_distances() -> None:
    for route in ROUTES.values():
        assert route_mainline_distance(route, route["distance_m"]) == 400.0


def test_direct_draft_uses_progress_and_caps_received_value() -> None:
    snapshot = [
        {"race_progress": 10.0, "offset": 0.0},
        {"race_progress": 12.0, "offset": 0.0},
        {"race_progress": 14.0, "offset": 0.2},
        {"race_progress": 16.0, "offset": 0.4},
        {"race_progress": 18.0, "offset": 0.6},
    ]
    own, received = calculate_draft(snapshot, 0)
    assert own > 0.0
    assert received <= MAX_DRAFT_RECEIVED_P


def test_draft_uses_speed_when_source_wake_is_initially_zero() -> None:
    snapshot = [
        {"race_progress": 10.0, "offset": 0.0, "speed": 60.0, "own_wake_p": 0.0},
        {"race_progress": 12.0, "offset": 0.0, "speed": 60.0, "own_wake_p": 0.0},
    ]

    _, received = calculate_draft(snapshot, 0)

    assert received > 0.0


def test_draft_distance_and_line_boundaries_are_deterministic() -> None:
    def received(gap: float, line_gap: float) -> float:
        snapshot = [
            {"id": "receiver", "race_progress": 100.0, "offset": 0.0},
            {"id": "source", "race_progress": 100.0 + gap, "offset": line_gap},
        ]
        return calculate_draft(snapshot, 0)[1]

    assert received(0.1, 0.0) > received(4.0, 0.0) > received(8.0, 0.0)
    assert received(4.0, 0.0) > 0.0
    assert received(4.0, 1.8) == 0.0
    assert received(8.0, 0.0) == 0.0


def test_draft_rejects_single_running_and_reversed_or_finished_sources() -> None:
    receiver = {"id": "receiver", "race_progress": 100.0, "offset": 0.0}
    assert calculate_draft([receiver], 0)[1] == 0.0
    assert calculate_draft(
        [receiver, {"id": "behind", "race_progress": 99.0, "offset": 0.0}], 0
    )[1] == 0.0
    assert calculate_draft(
        [receiver, {"id": "finished", "race_progress": 104.0, "offset": 0.0, "finished": True}],
        0,
    )[1] == 0.0


def test_draft_source_metadata_matches_primary_front_distance_and_line() -> None:
    race = M5Race("draft-metadata")
    race.start()
    player, source = race.racers[:2]
    for racer in race.racers[2:]:
        racer.finished = True
    player.race_progress = 100.0
    source.race_progress = 104.0
    player.offset = 0.0
    source.offset = 1.0

    race.tick()

    assert player.direct_source_ids == [source.racer_id]
    assert player.draft_source_ids == player.direct_source_ids
    assert player.primary_source_id == source.racer_id
    assert 0.0 < player.primary_gap_m <= 8.0
    assert player.primary_line_gap_m == 1.0
    assert player.draft_distance_m == player.primary_gap_m
    assert player.draft_line_gap_m == player.primary_line_gap_m
    assert player.direct_source_details[0]["id"] == source.racer_id
    assert player.direct_source_details[0]["gap"] == player.primary_gap_m
    assert player.direct_source_details[0]["line"] == player.primary_line_gap_m
    assert sum(
        detail["contribution_p"] for detail in player.direct_source_details
    ) == player.direct_draft_p


def test_finished_racer_cannot_provide_or_receive_draft() -> None:
    snapshot = [
        {"race_progress": 10.0, "offset": 0.0, "finished": False},
        {"race_progress": 12.0, "offset": 0.0, "finished": True},
    ]

    _, received = calculate_draft(snapshot, 0)
    _, finished_received = calculate_draft(snapshot, 1)

    assert received == 0.0
    assert finished_received == 0.0


def test_draft_assist_is_normalized_to_four_kmh() -> None:
    race = M5Race("draft-cap")
    race.start()
    player, source = race.racers[:2]
    for index, racer in enumerate(race.racers[2:], start=3):
        racer.finished = True
        racer.finish_order = index
        racer.finish_time = float(index)
    player.max_speed = 100.0
    player.speed = player.target_speed = 50.0
    player.race_progress = 100.0
    player.offset = source.offset = 0.0
    source.race_progress = 100.01
    source.own_wake_p = 0.18
    source.received_draft_p = 0.12
    player.received_draft_p = MAX_DRAFT_RECEIVED_P

    race.tick()

    assert player.received_draft_p <= MAX_DRAFT_RECEIVED_P
    assert player.speed <= 50.0 + DRAFT_ASSIST_MAX_KMH / 20.0


def test_received_draft_disappears_after_racer_order_changes() -> None:
    race = M5Race("order-change")
    race.start()
    player, source = race.racers[:2]
    player.race_progress = 100.0
    source.race_progress = 104.0
    player.offset = source.offset = 0.0
    player.speed = source.speed = 60.0

    race.tick()
    assert player.received_draft_p > 0.0

    player.race_progress = 110.0
    source.race_progress = 104.0
    race.tick()

    assert player.received_draft_p == 0.0


def test_late_race_keeps_draft_when_racers_remain_in_front() -> None:
    race = M5Race("late-draft")
    race.start()

    for _ in range(1000):
        race.tick()

    player, source = race.racers[:2]
    source.race_progress = player.race_progress + 4.0
    source.offset = player.offset
    race.tick()

    assert player.race_progress > 500.0
    assert player.received_draft_p > 0.0


def test_direct_and_chain_draft_are_separate_and_use_previous_tick_values() -> None:
    snapshot = [
        {"id": "a", "race_progress": 14.0, "offset": 0.0, "own_wake_p": 0.12},
        {
            "id": "b", "race_progress": 12.0, "offset": 0.0,
            "own_wake_p": 0.12, "direct_draft_p": 0.09, "chain_draft_p": 0.03,
        },
        {"id": "c", "race_progress": 10.0, "offset": 0.0, "own_wake_p": 0.12},
    ]
    race_m5_details = _calculate_draft_details(snapshot, 2)
    own, direct, chain, direct_sources, chain_sources = race_m5_details

    assert own > 0.0
    assert direct > 0.0
    assert chain > 0.0
    assert chain <= MAX_CHAIN_DRAFT_P
    assert direct_sources[0]["id"] == "b"
    assert chain_sources == ["b"]
    snapshot[1]["direct_draft_p"] = 0.0
    snapshot[1]["chain_draft_p"] = 0.0
    _, direct_without_chain, chain_without_chain, _, chain_sources_without_chain = (
        _calculate_draft_details(snapshot, 2)
    )
    assert direct_without_chain == direct
    assert chain_without_chain == 0.0
    assert chain_sources_without_chain == []


def test_direct_sources_are_limited_and_assist_reaches_four_kmh_at_cap() -> None:
    race = M5Race("draft-max")
    race.start()
    player = race.racers[0]
    for racer in race.racers[4:]:
        racer.finished = True
    player.max_speed = 100.0
    player.speed = player.target_speed = 50.0
    player.race_progress = 100.0
    player.offset = 0.0
    for index, source in enumerate(race.racers[1:4], start=1):
        source.race_progress = 100.1 + index
        source.offset = 0.0
        source.speed = 60.0
    player.received_draft_p = MAX_DRAFT_RECEIVED_P

    race.tick()

    assert len(player.direct_source_ids) == 3
    assert player.direct_draft_p == MAX_DRAFT_RECEIVED_P
    assert player.speed == 50.0 + DRAFT_ASSIST_MAX_KMH / 20.0


def test_tick_is_deterministic_and_never_exceeds_max_speed() -> None:
    first = M5Race("same", seed=4)
    second = M5Race("same", seed=4)
    first.start()
    second.start()
    for _ in range(20):
        first.tick()
        second.tick()
    assert first.tick_payload() == second.tick_payload()
    assert all(racer.speed <= racer.max_speed for racer in first.racers)


def test_contact_caps_a_catching_follower_without_regressing_progress() -> None:
    race = M5Race("contact")
    race.start()
    leader, follower = race.racers[:2]
    for racer in race.racers[2:]:
        racer.finished = True
    leader.race_progress = 100.0
    follower.race_progress = 99.9
    leader.offset = follower.offset = 0.0
    leader.speed = leader.target_speed = 50.0
    follower.speed = follower.target_speed = 75.0

    before = follower.race_progress
    race.tick()

    assert follower.race_progress >= before
    assert leader.contact and follower.contact
    assert follower.race_progress <= leader.race_progress - 1.5 or follower.race_progress == before
    assert follower.actual_speed_kmh <= follower.speed


def test_actual_speed_uses_resolved_progress_delta() -> None:
    race = M5Race("actual-speed")
    race.start()
    player = race.racers[0]
    for racer in race.racers[1:]:
        racer.finished = True
    before = player.race_progress

    race.tick()

    progress_delta = player.race_progress - before
    assert progress_delta > 0.0
    assert player.actual_speed_kmh == progress_delta / (1.0 / 20.0) * 3.6
    assert player.actual_speed_kmh >= 0.0


def test_distance_multiplier_is_one_on_straights_for_inner_center_outer() -> None:
    for offset in (-6.0, 0.0, 6.0):
        assert distance_multiplier(offset, 0.0) == 1.0
    deltas = [
        centerline_delta_from_kmh(60.0, 1.0, offset, 0.0)
        for offset in (-6.0, 0.0, 6.0)
    ]
    assert deltas == [deltas[0], deltas[0], deltas[0]]


def test_curve_inner_line_is_shorter_and_outer_line_is_longer() -> None:
    curvature = curvature_at(700.0)
    assert curvature > 0.0
    assert distance_multiplier(-6.0, curvature) < 1.0
    assert distance_multiplier(0.0, curvature) == 1.0
    assert distance_multiplier(6.0, curvature) > 1.0


def test_same_speed_and_time_have_inner_center_outer_progress_difference() -> None:
    curvature = curvature_at(700.0)
    inner = centerline_delta_from_kmh(60.0, 1.0, -6.0, curvature)
    center = centerline_delta_from_kmh(60.0, 1.0, 0.0, curvature)
    outer = centerline_delta_from_kmh(60.0, 1.0, 6.0, curvature)
    assert inner > center > outer


def test_actual_speed_matches_confirmed_progress_delta_on_curve() -> None:
    race = M5Race("curve-actual-speed")
    race.start()
    player = race.racers[0]
    for racer in race.racers[1:]:
        racer.finished = True
    player.distance = 700.0
    player.race_progress = 700.0
    player.offset = -6.0
    player.target_offset = -6.0
    player.speed = player.target_speed = 60.0
    before = player.race_progress
    race.tick(1.0)
    progress_delta = player.race_progress - before
    expected = centerline_delta_from_kmh(60.0, 1.0, -6.0, curvature_at(700.0, race.route))
    assert abs(progress_delta - expected) < 1e-12
    assert abs(player.actual_speed_kmh - expected * 3.6) < 1e-12


def test_draft_source_details_follow_post_move_snapshot_and_zero_outside_range() -> None:
    snapshot = [
        {"id": "receiver", "race_progress": 100.0, "offset": 0.0, "speed": 60.0},
        {"id": "near", "race_progress": 104.0, "offset": 1.0, "speed": 60.0},
        {"id": "behind", "race_progress": 99.0, "offset": 3.0, "speed": 60.0},
        {"id": "far", "race_progress": 109.0, "offset": 0.0, "speed": 60.0},
    ]
    _own, direct, chain, details, _chain_sources = _calculate_draft_details(snapshot, 0)
    assert direct > 0.0
    assert chain == 0.0
    assert details[0]["id"] == "near"
    assert details[0]["gap"] == 4.0
    assert details[0]["line"] == 1.0
    assert sum(item["contribution_p"] for item in details) == direct
    assert _calculate_draft_details(snapshot, 2)[1] == 0.0
    assert _calculate_draft_details(snapshot, 3)[1] == 0.0


def test_direct_source_details_are_capped_and_sum_to_direct_total() -> None:
    race = M5Race("source-contributions")
    race.start()
    player = race.racers[0]
    for racer in race.racers[4:]:
        racer.finished = True
    player.race_progress = 100.0
    player.offset = 0.0
    for index, source in enumerate(race.racers[1:4], start=1):
        source.race_progress = 100.1 + index
        source.offset = 0.0
        source.own_wake_p = 0.18
    race.tick()
    assert sum(
        detail["contribution_p"] for detail in player.direct_source_details
    ) == player.direct_draft_p
    assert player.direct_draft_p <= MAX_DRAFT_RECEIVED_P


def test_full_eight_racer_result_is_reproducible() -> None:
    results = []
    for race_id in ("repeat-a", "repeat-b"):
        race = M5Race(race_id, seed=11)
        race.start()
        for _ in range(20_000):
            race.tick()
            if race.finished:
                break
        results.append(race.result_payload()["results"])
    assert results[0] == results[1]


def test_finish_tick_reports_actual_progress_then_zero_afterwards() -> None:
    race = M5Race("actual-speed-finish")
    race.start()
    player = race.racers[0]
    for index, racer in enumerate(race.racers[1:], start=2):
        racer.finished = True
        racer.finish_order = index
        racer.finish_time = float(index)
    player.race_progress = 1999.0

    for _ in range(10):
        race.tick()
        if player.finished:
            break

    assert player.finished
    assert player.actual_speed_kmh > 0.0
    assert player.speed == 0.0
    race.tick()
    assert player.actual_speed_kmh == 0.0


def test_tick_reports_deterministic_elapsed_seconds() -> None:
    race = M5Race("elapsed")
    start = race.start()
    assert start["elapsed_seconds"] == 0.0
    tick = race.tick()
    assert tick["tick"] == 1
    assert tick["elapsed_seconds"] == 1 / 20


def test_input_does_not_accept_client_supplied_p_or_speed() -> None:
    race = M5Race()
    race.start()
    race.receive_input("player-1", {
        "target_speed": 60.0, "target_offset": 2.0,
        "draft_assist": 1.0, "received_draft_p": 1.0, "speed": 9999.0,
    })
    assert "draft_assist" not in race.inputs["player-1"]
    race.tick()
    assert race.racers[0].received_draft_p <= 0.24
    assert race.racers[0].speed <= race.racers[0].max_speed


def test_all_eight_racers_finish_and_result_is_available() -> None:
    race = M5Race("finish-regression")
    race.start()

    for _ in range(20_000):
        race.tick()
        if race.finished:
            break

    assert race.finished
    assert race.finish_count == 8
    assert all(racer.finished for racer in race.racers)
    result = race.result_payload()
    assert result["t"] == "race_result"
    assert len(result["results"]) == 8
    assert result["elapsed_seconds"] == race.tick_number / 20
    assert all(item["finish_time"] >= 0.0 for item in result["results"])
    assert all(item["time"] == item["finish_time"] for item in result["results"])
    assert [item["rank"] for item in result["results"]] == list(range(1, 9))
    assert all(item["finish_order"] == item["rank"] for item in result["results"])
    assert all(racer.speed == 0.0 for racer in race.racers)
    finish_times = [item["finish_time"] for item in result["results"]]
    assert finish_times == sorted(finish_times)
    assert max(finish_times) - min(finish_times) > 0.1
    assert len({round(finish_time, 1) for finish_time in finish_times}) > 1
    race.tick()
    assert all(racer.actual_speed_kmh == 0.0 for racer in race.racers)


def test_finish_time_interpolates_crossing_and_orders_by_time() -> None:
    race = M5Race("finish-interpolation")
    race.start()
    first, second = race.racers[:2]
    for index, racer in enumerate(race.racers[2:], start=3):
        racer.finished = True
        racer.finish_order = index
        racer.finish_time = float(index)
    race._tick_start_progress = {
        first.racer_id: 1990.0,
        second.racer_id: 1999.2,
    }
    first.race_progress = 2010.0
    second.race_progress = 2001.0
    race.tick_number = 1

    race._mark_finishes()

    assert abs(second.finish_time - (0.05 / 1.8) / 20.0) < 1e-9
    assert first.finish_time == 0.023125
    assert second.finish_order == 1
    assert first.finish_order == 2
    result = race.result_payload()["results"]
    assert [item["id"] for item in result[:2]] == [second.racer_id, first.racer_id]
    assert [item["rank"] for item in result[:2]] == [1, 2]


def test_result_uses_finish_order_not_final_progress() -> None:
    race = M5Race("result-order")
    race.start()
    for index, racer in enumerate(race.racers):
        racer.finished = True
        racer.finish_order = index + 1
        racer.finish_time = float(index + 1)
        racer.race_progress = float(2000 - index * 10)

    results = race.result_payload()["results"]

    assert [item["id"] for item in results] == [r.racer_id for r in race.racers]
    assert [item["rank"] for item in results] == list(range(1, 9))
    assert [item["time"] for item in results] == [float(i) for i in range(1, 9)]


def test_result_ranks_by_time_then_finish_order_then_racer_id() -> None:
    race = M5Race("result-tiebreak")
    race.start()
    for racer in race.racers:
        racer.finished = True
    race.racers[0].finish_time = 10.0
    race.racers[0].finish_order = 2
    race.racers[1].finish_time = 10.0
    race.racers[1].finish_order = 1
    for index, racer in enumerate(race.racers[2:], start=3):
        racer.finish_time = float(index)
        racer.finish_order = index

    results = race.result_payload()["results"]

    assert [item["id"] for item in results] == [
        "cpu-2", "cpu-3", "cpu-4", "cpu-5",
        "cpu-6", "cpu-7", "cpu-1", "player-1",
    ]
    assert [item["time"] for item in results] == [
        3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 10.0, 10.0,
    ]
    assert [item["rank"] for item in results] == list(range(1, 9))
