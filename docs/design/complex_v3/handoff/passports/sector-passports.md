# Комплекс v3 — паспорта секторов

Артефакт: `PASSPORTS-01`

Статус: `verified`; точная структурированная геометрия подключается из `geometry/complex-handoff.json`.

## U-EMERGENCY

- Passport ID: `PASS-U-EMERGENCY`
- Detail ID: `DETAIL-U-EMERGENCY`
- Level: `LV-U`
- Plan style: `caretaker-style-b-v1`
- Source: `../../u_emergency.html` (full sector geometry)
- Parent boundary XZ: `[-110.0, -13.0] → [-62.0, 15.0] m`
- Local origin XYZ: `[-110.0, 0.0, -13.0]`
- Neighbors: `U-MEDBAY`, `U-PAX`, `U-ROUTE-A`
- Allowed subdivisions: `capsule_hall`, `internal_technical_room`, `hermetic_vestibule`, `distribution_hall`
- Clearance profile: `passenger` — {'minimum_width': 1.2, 'minimum_height': 2.4, 'turning_envelope': 1.5}
- Reserved volumes: `capsule_service_bays`

Required connections:

- `E-U01` → `U-PAX`: `passenger`, traversable `true`.
- `E-U02` → `U-ROUTE-A`: `service`, traversable `true`.
- `E-U02A` → `U-MEDBAY`: `short-side-passage`, traversable `true`.

---

## U-MEDBAY

- Passport ID: `PASS-U-MEDBAY`
- Detail ID: `DETAIL-U-MEDBAY`
- Level: `LV-U`
- Plan style: `caretaker-style-b-v1`
- Source: `../../u_medbay.html` (full sector geometry)
- Parent boundary XZ: `[-102.0, 7.0] → [-88.0, 15.0] m`
- Local origin XYZ: `[-102.0, 0.0, 7.0]`
- Neighbors: `U-EMERGENCY`
- Allowed subdivisions: `triage`, `clean_corridor`, `procedure_room`, `observation_ward`, `clean_store`, `sanitary_airlock`, `medical_post`
- Clearance profile: `passenger` — {'minimum_width': 1.2, 'minimum_height': 2.4, 'turning_envelope': 1.5}
- Reserved volumes: нет

Required connections:

- `E-U02A` → `U-EMERGENCY`: `short-side-passage`, traversable `true`.

---

## U-ROUTE-A

- Passport ID: `PASS-U-ROUTE-A`
- Detail ID: `DETAIL-U-ROUTE-A`
- Level: `LV-U`
- Plan style: `caretaker-style-b-v1`
- Source: `../../u_route_a.html` (full sector geometry)
- Parent boundary XZ: `[-64.0, -8.0] → [-45.0, 14.0] m`
- Local origin XYZ: `[-64.0, 0.0, -8.0]`
- Neighbors: `L-ARCHIVE-A`, `U-EMERGENCY`
- Allowed subdivisions: `hall_access`, `service_store`, `ventilation_room`, `stair_landing`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: `ventilation_plant`
- Anchors: `A-ROUTE-A`

Required connections:

- `E-U02` → `U-EMERGENCY`: `service`, traversable `true`.
- `E-X01` → `L-ARCHIVE-A`: `stair`, traversable `true`.

---

## U-DOMESTIC

- Passport ID: `PASS-U-DOMESTIC`
- Detail ID: `DETAIL-U-DOMESTIC`
- Level: `LV-U`
- Plan style: `caretaker-style-b-v1`
- Source: `../../u_domestic.html` (full sector geometry)
- Parent boundary XZ: `[-61.0, -17.0] → [-33.0, 15.0] m`
- Local origin XYZ: `[-61.0, 0.0, -17.0]`
- Neighbors: `U-PAX`
- Allowed subdivisions: `canteen`, `kitchen`, `dry_store`, `cold_store`, `staff_vestibule`, `locker_room`, `shower_room`, `rest_room`
- Clearance profile: `passenger` — {'minimum_width': 1.2, 'minimum_height': 2.4, 'turning_envelope': 1.5}
- Reserved volumes: нет

Required connections:

- `E-U03` → `U-PAX`: `passenger`, traversable `true`.

---

## U-CONTROL

- Passport ID: `PASS-U-CONTROL`
- Detail ID: `DETAIL-U-CONTROL`
- Level: `LV-U`
- Plan style: `caretaker-style-b-v1`
- Source: `../../u_control.html` (full sector geometry)
- Parent boundary XZ: `[-32.0, -13.0] → [-8.0, 15.0] m`
- Local origin XYZ: `[-32.0, 0.0, -13.0]`
- Neighbors: `U-PAX`
- Allowed subdivisions: `command_office`, `coordination_room`, `communications_room`, `operator_hall`, `access_buffer`, `access_vestibule`, `duty_support`, `fire_vestibule`, `power_buffer`, `network_node`, `server_room`, `service_aisle`, `east_access`
- Clearance profile: `passenger` — {'minimum_width': 1.2, 'minimum_height': 2.4, 'turning_envelope': 1.5}
- Reserved volumes: `access_buffer`, `server_cooling`

Required connections:

- `E-U04` → `U-PAX`: `passenger`, traversable `true`.

---

## U-CENTRAL-CORE

- Passport ID: `PASS-U-CENTRAL-CORE`
- Detail ID: `DETAIL-U-CENTRAL-CORE`
- Level: `LV-U`
- Plan style: `caretaker-style-b-v1`
- Source: `../../u_central_core.html` (full sector geometry)
- Parent boundary XZ: `[-7.75, -6.0] → [7.75, 15.0] m`
- Local origin XYZ: `[-7.75, 0.0, -6.0]`
- Neighbors: `L-CENTRAL-CORE`, `U-PAX`
- Allowed subdivisions: `access_lobby`, `lift_lobby`, `passenger_elevator`, `main_stair`, `service_access`, `electrical_room`
- Clearance profile: `passenger` — {'minimum_width': 1.2, 'minimum_height': 2.4, 'turning_envelope': 1.5}
- Reserved volumes: `lift_shaft`
- Anchors: `A-MAIN-CORE`

Required connections:

- `E-U05` → `U-PAX`: `passenger`, traversable `true`.
- `E-X02` → `L-CENTRAL-CORE`: `passenger-vertical`, traversable `true`.

---

## U-EAST-SUPPORT

- Passport ID: `PASS-U-EAST-SUPPORT`
- Detail ID: `DETAIL-U-EAST-SUPPORT`
- Level: `LV-U`
- Plan style: `caretaker-style-b-v1`
- Source: `../../u_east_support.html` (full sector geometry)
- Parent boundary XZ: `[10.0, -13.0] → [32.0, 15.0] m`
- Local origin XYZ: `[10.0, 0.0, -13.0]`
- Neighbors: `L-EAST-STAIR`, `U-PAX`
- Allowed subdivisions: `support_corridor`, `supply_store`, `cleaning_room`, `duty_room`, `service_vestibule`, `fire_vestibule`, `emergency_stair`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: нет
- Anchors: `A-EAST-STAIR`

Required connections:

- `E-U06` → `U-PAX`: `passenger`, traversable `true`.
- `E-X03` → `L-EAST-STAIR`: `emergency-stair`, traversable `true`.

---

## U-CHAMBER-4

- Passport ID: `PASS-U-CHAMBER-4`
- Detail ID: `DETAIL-U-CHAMBER-4`
- Level: `LV-U`
- Plan style: `caretaker-style-b-v1`
- Source: `../../u_chamber_4.html` (serial containment geometry; chamber-specific equipment excluded)
- Parent boundary XZ: `[-110.0, 37.0] → [-82.0, 64.0] m`
- Local origin XYZ: `[-110.0, 0.0, 37.0]`
- Neighbors: `U-FRT`, `U-PAX`
- Allowed subdivisions: `passenger_airlock`, `control_post`, `containment_chamber`, `technical_gallery`, `cargo_airlock`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: `capsule_service_volume`

Required connections:

- `E-U07` → `U-PAX`: `controlled-passenger`, traversable `true`.
- `E-U11` → `U-FRT`: `cargo-hermetic`, traversable `false`, state `closed`.

---

## U-SECURITY

- Passport ID: `PASS-U-SECURITY`
- Detail ID: `DETAIL-U-SECURITY`
- Level: `LV-U`
- Plan style: `caretaker-style-b-v1`
- Source: `../../u_security.html` (full sector geometry)
- Parent boundary XZ: `[-32.0, 31.0] → [0.0, 52.0] m`
- Local origin XYZ: `[-32.0, 0.0, 31.0]`
- Neighbors: `U-FRT`, `U-PAX`
- Allowed subdivisions: `access_vestibule`, `duty_room`, `equipment_room`, `armory`, `two_gate_checkpoint`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: `secure_storage`

Required connections:

- `E-U08` → `U-PAX`: `service`, traversable `true`.
- `E-U09` → `U-FRT`: `controlled-transition`, traversable `true`.

---

## U-CHAMBER-6

- Passport ID: `PASS-U-CHAMBER-6`
- Detail ID: `DETAIL-U-CHAMBER-6`
- Level: `LV-U`
- Plan style: `caretaker-style-b-v1`
- Source: `../../u_chamber_6.html` (full sector geometry)
- Parent boundary XZ: `[0.0, 29.0] → [32.0, 64.0] m`
- Local origin XYZ: `[0.0, 0.0, 29.0]`
- Neighbors: `U-FRT`, `U-PAX`
- Allowed subdivisions: `passenger_airlock`, `control_post`, `containment_chamber`, `technical_gallery`, `cargo_airlock`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: `capsule_service_volume`, `sleep_entry_device_volume`

Required connections:

- `E-U10` → `U-PAX`: `controlled-passenger`, traversable `true`.
- `E-U12` → `U-FRT`: `cargo-hermetic`, traversable `false`, state `closed`.

---

## U-FREIGHT

- Passport ID: `PASS-U-FREIGHT`
- Detail ID: `DETAIL-U-FREIGHT`
- Level: `LV-U`
- Plan style: `caretaker-style-b-v1`
- Source: `../../u_freight.html` (full sector geometry)
- Parent boundary XZ: `[-16.0, 64.0] → [30.0, 82.0] m`
- Local origin XYZ: `[-16.0, 0.0, 64.0]`
- Neighbors: `L-FREIGHT-SERVICE`, `U-FRT`
- Allowed subdivisions: `unloading_bay`, `inspection_lane`, `isolation_bay`, `operator_room`, `service_walkway`, `freight_lift`
- Clearance profile: `heavy` — {'minimum_width': 4.5, 'minimum_height': 4.5, 'turning_envelope': 7.0}
- Reserved volumes: `lift_shaft`, `platform_turning_envelope`
- Anchors: `A-FREIGHT-LIFT`, `A-HEAVY-SPINE`

Required connections:

- `E-U13` → `U-FRT`: `freight`, traversable `true`.
- `E-X04` → `L-FREIGHT-SERVICE`: `freight-lift`, traversable `true`.

---

## L-OLD-CORE

- Passport ID: `PASS-L-OLD-CORE`
- Detail ID: `DETAIL-L-OLD-CORE`
- Level: `LV-L`
- Plan style: `caretaker-style-b-v1`
- Source: `../../l_old_core.html` (full sector geometry)
- Parent boundary XZ: `[-84.0, -14.0] → [-62.0, 21.0] m`
- Local origin XYZ: `[-84.0, -6.0, -14.0]`
- Neighbors: `L-ARCHIVE-A`, `L-CHAMBER-1`, `L-OLD-RECEIVING`, `L-PAX`, `T-OLD-ACCESS`
- Allowed subdivisions: `distribution_hall`, `control_access`, `reserve_control`, `relay_room`, `senior_room`
- Clearance profile: `passenger` — {'minimum_width': 1.2, 'minimum_height': 2.4, 'turning_envelope': 1.5}
- Reserved volumes: нет
- Anchors: `A-OLD-STAIR`

Required connections:

- `E-L01` → `L-PAX`: `passenger`, traversable `true`.
- `E-L02` → `L-CHAMBER-1`: `combined-historic-threshold`, traversable `true`.
- `E-L03` → `L-ARCHIVE-A`: `passenger`, traversable `true`.
- `E-L04` → `L-OLD-RECEIVING`: `historic-mixed`, traversable `true`.
- `E-X06` → `T-OLD-ACCESS`: `old-stair`, traversable `true`.

---

## L-CHAMBER-1

- Passport ID: `PASS-L-CHAMBER-1`
- Detail ID: `DETAIL-L-CHAMBER-1`
- Level: `LV-L`
- Plan style: `caretaker-style-b-v1`
- Source: `../../l_chamber_1.html` (full sector geometry)
- Parent boundary XZ: `[-110.0, -8.0] → [-83.0, 17.0] m`
- Local origin XYZ: `[-110.0, -6.0, -8.0]`
- Neighbors: `L-OLD-CORE`
- Allowed subdivisions: `combined_vestibule`, `control_post`, `mechanical_cage`
- Clearance profile: `heavy` — {'minimum_width': 4.5, 'minimum_height': 4.5, 'turning_envelope': 7.0}
- Reserved volumes: `restraint_service_volume`

Required connections:

- `E-L02` → `L-OLD-CORE`: `combined-historic-threshold`, traversable `true`.

---

## L-ARCHIVE-A

- Passport ID: `PASS-L-ARCHIVE-A`
- Detail ID: `DETAIL-L-ARCHIVE-A`
- Level: `LV-L`
- Plan style: `caretaker-style-b-v1`
- Source: `../../l_archive_a.html` (full sector geometry)
- Parent boundary XZ: `[-61.0, -14.0] → [-41.0, 15.0] m`
- Local origin XYZ: `[-61.0, -6.0, -14.0]`
- Neighbors: `L-OLD-CORE`, `U-ROUTE-A`
- Allowed subdivisions: `archive_main`, `route_a_partition`, `route_a_service_passage`, `route_a_stair_lobby`, `route_a_stair`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: `archive_shelving`
- Anchors: `A-ROUTE-A`

Required connections:

- `E-X01` → `U-ROUTE-A`: `stair`, traversable `true`.
- `E-L03` → `L-OLD-CORE`: `passenger`, traversable `true`.

---

## L-OLD-RECEIVING

- Passport ID: `PASS-L-OLD-RECEIVING`
- Detail ID: `DETAIL-L-OLD-RECEIVING`
- Level: `LV-L`
- Plan style: `caretaker-style-b-v1`
- Source: `../../l_old_receiving.html` (full sector geometry)
- Parent boundary XZ: `[-110.0, 43.0] → [-72.0, 68.0] m`
- Local origin XYZ: `[-110.0, -6.0, 43.0]`
- Neighbors: `L-FRT`, `L-OLD-CORE`, `U-FRT`
- Allowed subdivisions: `receiving_hall`, `inspection_post`, `tunnel_landing`
- Clearance profile: `heavy` — {'minimum_width': 4.5, 'minimum_height': 4.5, 'turning_envelope': 7.0}
- Reserved volumes: `old_tunnel_mouth`

Required connections:

- `E-X05` → `U-FRT`: `old-inclined-tunnel`, traversable `true`.
- `E-L04` → `L-OLD-CORE`: `historic-mixed`, traversable `true`.
- `E-L12` → `L-FRT`: `freight`, traversable `true`.

---

## L-CHAMBER-2

- Passport ID: `PASS-L-CHAMBER-2`
- Detail ID: `DETAIL-L-CHAMBER-2`
- Level: `LV-L`
- Plan style: `caretaker-style-b-v1`
- Source: `../../l_chamber_2.html` (full sector geometry)
- Parent boundary XZ: `[-74.0, 27.0] → [-48.0, 60.0] m`
- Local origin XYZ: `[-74.0, -6.0, 27.0]`
- Neighbors: `L-FRT`, `L-PAX`
- Allowed subdivisions: `control_post`, `passenger_airlock`, `containment_chamber`, `gas_equipment_room`, `cargo_vestibule`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: `restraint_platform_volume`

Required connections:

- `E-L05` → `L-PAX`: `controlled-passenger`, traversable `true`.
- `E-L13` → `L-FRT`: `cargo-hermetic`, traversable `false`, state `closed`.

---

## L-SLEEP-LAB

- Passport ID: `PASS-L-SLEEP-LAB`
- Detail ID: `DETAIL-L-SLEEP-LAB`
- Level: `LV-L`
- Plan style: `caretaker-style-b-v1`
- Source: `../../l_sleep_lab.html` (full sector geometry)
- Parent boundary XZ: `[-34.0, -12.0] → [-12.0, 10.0] m`
- Local origin XYZ: `[-34.0, -6.0, -12.0]`
- Neighbors: `L-PAX`
- Allowed subdivisions: `preparation_room`, `neuro_monitoring`, `observation_room`, `equipment_room`, `internal_corridor`
- Clearance profile: `passenger` — {'minimum_width': 1.2, 'minimum_height': 2.4, 'turning_envelope': 1.5}
- Reserved volumes: `bed_service_envelopes`

Required connections:

- `E-L06` → `L-PAX`: `passenger`, traversable `true`.

---

## L-CHAMBER-3

- Passport ID: `PASS-L-CHAMBER-3`
- Detail ID: `DETAIL-L-CHAMBER-3`
- Level: `LV-L`
- Plan style: `caretaker-style-b-v1`
- Source: `../../l_chamber_3.html` (full sector geometry)
- Parent boundary XZ: `[-36.0, 27.0] → [-10.0, 60.0] m`
- Local origin XYZ: `[-36.0, -6.0, 27.0]`
- Neighbors: `L-FRT`, `L-PAX`
- Allowed subdivisions: `passenger_airlock`, `operator_gallery`, `containment_chamber`, `diagnostics_room`, `cargo_airlock`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: `capsule_service_volume`

Required connections:

- `E-L07` → `L-PAX`: `controlled-passenger`, traversable `true`.
- `E-L14` → `L-FRT`: `cargo-hermetic`, traversable `false`, state `closed`.

---

## L-SERVICE-INTERCHANGE

- Passport ID: `PASS-L-SERVICE-INTERCHANGE`
- Detail ID: `DETAIL-L-SERVICE-INTERCHANGE`
- Level: `LV-L`
- Plan style: `caretaker-style-b-v1`
- Source: `../../l_service_interchange.html` (full sector geometry)
- Parent boundary XZ: `[-48.0, 42.0] → [-34.0, 60.0] m`
- Local origin XYZ: `[-48.0, -6.0, 42.0]`
- Neighbors: `L-FRT`, `L-PAX`, `T-CIRCULATION`
- Allowed subdivisions: `service_lobby`, `double_airlock`, `service_stair`, `electrical_room`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: нет
- Anchors: `A-SERVICE-STAIR`

Required connections:

- `E-L08` → `L-PAX`: `service`, traversable `true`.
- `E-L15` → `L-FRT`: `controlled-transition`, traversable `true`.
- `E-X07` → `T-CIRCULATION`: `service-stair`, traversable `true`.

---

## L-CENTRAL-CORE

- Passport ID: `PASS-L-CENTRAL-CORE`
- Detail ID: `DETAIL-L-CENTRAL-CORE`
- Level: `LV-L`
- Plan style: `caretaker-style-b-v1`
- Source: `../../l_central_core.html` (full sector geometry)
- Parent boundary XZ: `[-7.75, -6.0] → [7.75, 15.0] m`
- Local origin XYZ: `[-7.75, -6.0, -6.0]`
- Neighbors: `L-PAX`, `T-EAST-VERTICAL`, `U-CENTRAL-CORE`
- Allowed subdivisions: `access_lobby`, `lift_lobby`, `passenger_elevator`, `main_stair`, `service_access`, `electrical_room`
- Clearance profile: `passenger` — {'minimum_width': 1.2, 'minimum_height': 2.4, 'turning_envelope': 1.5}
- Reserved volumes: `lift_shaft`
- Anchors: `A-MAIN-CORE`

Required connections:

- `E-X02` → `U-CENTRAL-CORE`: `passenger-vertical`, traversable `true`.
- `E-L09` → `L-PAX`: `passenger`, traversable `true`.
- `E-X08` → `T-EAST-VERTICAL`: `passing-shaft`, traversable `false`, state `no-stop`.

---

## L-EAST-STAIR

- Passport ID: `PASS-L-EAST-STAIR`
- Detail ID: `DETAIL-L-EAST-STAIR`
- Level: `LV-L`
- Plan style: `caretaker-style-b-v1`
- Source: `../../l_east_stair.html` (east stair crop only)
- Parent boundary XZ: `[20.0, 6.0] → [32.0, 15.0] m`
- Local origin XYZ: `[20.0, -6.0, 6.0]`
- Neighbors: `L-PAX`, `T-EAST-VERTICAL`, `U-EAST-SUPPORT`
- Allowed subdivisions: `fire_vestibule`, `emergency_stair`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: нет
- Anchors: `A-EAST-STAIR`

Required connections:

- `E-X03` → `U-EAST-SUPPORT`: `emergency-stair`, traversable `true`.
- `E-L10` → `L-PAX`: `passenger`, traversable `true`.
- `E-X09` → `T-EAST-VERTICAL`: `emergency-stair`, traversable `true`.

---

## L-CHAMBER-5

- Passport ID: `PASS-L-CHAMBER-5`
- Detail ID: `DETAIL-L-CHAMBER-5`
- Level: `LV-L`
- Plan style: `caretaker-style-b-v1`
- Source: `../../l_chamber_5.html` (serial containment geometry; chamber-specific equipment excluded)
- Parent boundary XZ: `[4.0, 27.0] → [32.0, 60.0] m`
- Local origin XYZ: `[4.0, -6.0, 27.0]`
- Neighbors: `L-FRT`, `L-PAX`
- Allowed subdivisions: `passenger_airlock`, `control_post`, `containment_chamber`, `technical_gallery`, `cargo_airlock`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: `capsule_service_volume`

Required connections:

- `E-L11` → `L-PAX`: `controlled-passenger`, traversable `true`.
- `E-L16` → `L-FRT`: `cargo-hermetic`, traversable `false`, state `closed`.

---

## L-FREIGHT-SERVICE

- Passport ID: `PASS-L-FREIGHT-SERVICE`
- Detail ID: `DETAIL-L-FREIGHT-SERVICE`
- Level: `LV-L`
- Plan style: `caretaker-style-b-v1`
- Source: `../../l_freight_service.html` (full sector geometry)
- Parent boundary XZ: `[-38.0, 60.0] → [30.0, 82.0] m`
- Local origin XYZ: `[-38.0, -6.0, 60.0]`
- Neighbors: `L-FRT`, `T-FREIGHT`, `U-FREIGHT`
- Allowed subdivisions: `ventilation_room`, `electrical_room`, `service_zone`, `freight_platform`, `shaft_bypass`, `freight_lift`
- Clearance profile: `heavy` — {'minimum_width': 4.5, 'minimum_height': 4.5, 'turning_envelope': 7.0}
- Reserved volumes: `lift_shaft`, `platform_turning_envelope`
- Anchors: `A-FREIGHT-LIFT`, `A-HEAVY-SPINE`

Required connections:

- `E-X04` → `U-FREIGHT`: `freight-lift`, traversable `true`.
- `E-L17` → `L-FRT`: `freight`, traversable `true`.
- `E-X10` → `T-FREIGHT`: `freight-lift`, traversable `true`.

---

## T-ENERGY

- Passport ID: `PASS-T-ENERGY`
- Detail ID: `DETAIL-T-ENERGY`
- Level: `LV-T`
- Plan style: `caretaker-style-b-v1`
- Source: `../../t_energy.html` (full sector geometry)
- Parent boundary XZ: `[-110.0, -15.0] → [-65.0, 15.0] m`
- Local origin XYZ: `[-110.0, -11.5, -15.0]`
- Neighbors: `T-TECH`
- Allowed subdivisions: `generator_hall`, `fire_vestibule`, `switchgear_room`, `cooling_room`, `service_approach`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: `generator_service_envelope`

Required connections:

- `E-T01` → `T-TECH`: `service`, traversable `true`.

---

## T-WORKSHOP

- Passport ID: `PASS-T-WORKSHOP`
- Detail ID: `DETAIL-T-WORKSHOP`
- Level: `LV-T`
- Plan style: `caretaker-style-b-v1`
- Source: `../../t_workshop.html` (full sector geometry)
- Parent boundary XZ: `[-65.0, -15.0] → [-30.0, 15.0] m`
- Local origin XYZ: `[-65.0, -11.5, -15.0]`
- Neighbors: `T-TECH`
- Allowed subdivisions: `workshop`, `parts_store`, `internal_cargo_opening`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: `cart_turning_envelope`

Required connections:

- `E-T02` → `T-TECH`: `service`, traversable `true`.

---

## T-OLD-ACCESS

- Passport ID: `PASS-T-OLD-ACCESS`
- Detail ID: `DETAIL-T-OLD-ACCESS`
- Level: `LV-T`
- Plan style: `caretaker-style-b-v1`
- Source: `../../t_old_access.html` (full sector geometry)
- Parent boundary XZ: `[-102.0, 20.0] → [-78.0, 45.0] m`
- Local origin XYZ: `[-102.0, -11.5, 20.0]`
- Neighbors: `L-OLD-CORE`, `T-TECH`
- Allowed subdivisions: `old_stair`, `service_vestibule`, `old_core_substation`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: нет
- Anchors: `A-OLD-STAIR`

Required connections:

- `E-X06` → `L-OLD-CORE`: `old-stair`, traversable `true`.
- `E-T03` → `T-TECH`: `service`, traversable `true`.

---

## T-EAST-VERTICAL

- Passport ID: `PASS-T-EAST-VERTICAL`
- Detail ID: `DETAIL-T-EAST-VERTICAL`
- Level: `LV-T`
- Plan style: `caretaker-style-b-v1`
- Source: `../../t_east_vertical.html` (full sector geometry)
- Parent boundary XZ: `[18.0, -12.0] → [32.0, 20.0] m`
- Local origin XYZ: `[18.0, -11.5, -12.0]`
- Neighbors: `L-CENTRAL-CORE`, `L-EAST-STAIR`, `T-TECH`
- Allowed subdivisions: `passenger_shaft_no_stop`, `new_substation`, `fire_vestibule`, `east_emergency_stair`, `closed_cable_pit`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: `passenger_lift_shaft`, `closed_cable_pit`
- Anchors: `A-MAIN-CORE`, `A-EAST-STAIR`

Required connections:

- `E-X08` → `L-CENTRAL-CORE`: `passing-shaft`, traversable `false`, state `no-stop`.
- `E-X09` → `L-EAST-STAIR`: `emergency-stair`, traversable `true`.
- `E-T04` → `T-TECH`: `service`, traversable `true`.

---

## T-UTILITIES

- Passport ID: `PASS-T-UTILITIES`
- Detail ID: `DETAIL-T-UTILITIES`
- Level: `LV-T`
- Plan style: `caretaker-style-b-v1`
- Source: `../../t_utilities.html` (full sector geometry)
- Parent boundary XZ: `[-57.0, 20.0] → [18.0, 56.0] m`
- Local origin XYZ: `[-57.0, -11.5, 20.0]`
- Neighbors: `T-TECH`
- Allowed subdivisions: `late_block_substation`, `ventilation_room`, `reagent_room`, `drainage_room`, `cable_gallery`, `fire_vestibule`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: `sealed_service_ducts`
- Anchors: `A-SERVICE-STAIR`

Required connections:

- `E-T05` → `T-TECH`: `service`, traversable `true`.

---

## T-FREIGHT

- Passport ID: `PASS-T-FREIGHT`
- Detail ID: `DETAIL-T-FREIGHT`
- Level: `LV-T`
- Plan style: `caretaker-style-b-v1`
- Source: `../../t_freight.html` (full sector geometry)
- Parent boundary XZ: `[-20.0, 60.0] → [30.0, 82.0] m`
- Local origin XYZ: `[-20.0, -11.5, 60.0]`
- Neighbors: `L-FREIGHT-SERVICE`, `T-FRT`
- Allowed subdivisions: `heavy_spine`, `service_reception`, `freight_lift`, `service_bypass`
- Clearance profile: `heavy` — {'minimum_width': 4.5, 'minimum_height': 4.5, 'turning_envelope': 7.0}
- Reserved volumes: `lift_shaft`, `platform_turning_envelope`
- Anchors: `A-FREIGHT-LIFT`, `A-HEAVY-SPINE`

Required connections:

- `E-X10` → `L-FREIGHT-SERVICE`: `freight-lift`, traversable `true`.
- `E-T08` → `T-FRT`: `freight`, traversable `true`.

---

## T-CIRCULATION

- Passport ID: `PASS-T-CIRCULATION`
- Detail ID: `DETAIL-T-CIRCULATION`
- Level: `LV-T`
- Plan style: `caretaker-style-b-v1`
- Source: `../../t_circulation.html` (full sector geometry)
- Parent boundary XZ: `[-105.0, 15.0] → [32.0, 68.0] m`
- Local origin XYZ: `[-105.0, -11.5, 15.0]`
- Neighbors: `L-SERVICE-INTERCHANGE`, `T-FRT`, `T-TECH`
- Allowed subdivisions: `main_service_corridor`, `cable_gallery`, `west_controlled_transition`, `east_controlled_transition`, `heavy_spine`
- Clearance profile: `service` — {'minimum_width': 1.5, 'minimum_height': 2.5, 'turning_envelope': 1.8}
- Reserved volumes: `non_transit_engineering_volume`
- Anchors: `A-OLD-STAIR`, `A-SERVICE-STAIR`, `A-MAIN-CORE`, `A-EAST-STAIR`, `A-FREIGHT-LIFT`, `A-HEAVY-SPINE`

Required connections:

- `E-X07` → `L-SERVICE-INTERCHANGE`: `service-stair`, traversable `true`.
- `E-T06` → `T-TECH`: `service`, traversable `true`.
- `E-T07` → `T-FRT`: `controlled-transition-pair`, traversable `true`.

---
