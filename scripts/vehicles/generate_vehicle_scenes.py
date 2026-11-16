#!/usr/bin/env python3
"""
Generate vehicle scenes for all 22 vehicles defined in VehicleManager.
Each scene inherits from the base vehicle scene and customizes properties.
"""

import os

VEHICLE_DEFINITIONS = {
    "sultan_rs": {
        "id": "sultan_rs",
        "name": "Sultan RS",
        "class": "SPORTS",
        "price": 75000,
        "stats": {"speed": 95, "acceleration": 90, "handling": 85, "braking": 80, "durability": 60},
        "color": (0.8, 0.1, 0.1),  # Red
        "mesh_size": (2.0, 1.0, 4.2),
        "collision_size": (2.2, 1.2, 4.5),
        "wheel_positions": {
            "FR": (1.1, 0.5, 1.8),
            "FL": (-1.1, 0.5, 1.8),
            "RR": (1.1, 0.5, -1.8),
            "RL": (-1.1, 0.5, -1.8),
        }
    },
    "comet_sr": {
        "id": "comet_sr",
        "name": "Comet SR",
        "class": "SPORTS",
        "price": 120000,
        "stats": {"speed": 98, "acceleration": 95, "handling": 88, "braking": 85, "durability": 55},
        "color": (0.9, 0.9, 0.1),  # Yellow
        "mesh_size": (1.9, 0.9, 4.0),
        "collision_size": (2.1, 1.1, 4.3),
        "wheel_positions": {
            "FR": (1.05, 0.45, 1.7),
            "FL": (-1.05, 0.45, 1.7),
            "RR": (1.05, 0.45, -1.7),
            "RL": (-1.05, 0.45, -1.7),
        }
    },
    "t20": {
        "id": "t20",
        "name": "T20",
        "class": "SPORTS",
        "price": 250000,
        "stats": {"speed": 100, "acceleration": 98, "handling": 90, "braking": 90, "durability": 50},
        "color": (0.1, 0.8, 0.8),  # Cyan
        "mesh_size": (1.8, 0.85, 3.9),
        "collision_size": (2.0, 1.05, 4.2),
        "wheel_positions": {
            "FR": (1.0, 0.4, 1.65),
            "FL": (-1.0, 0.4, 1.65),
            "RR": (1.0, 0.4, -1.65),
            "RL": (-1.0, 0.4, -1.65),
        }
    },
    "zentorno": {
        "id": "zentorno",
        "name": "Zentorno",
        "class": "SPORTS",
        "price": 300000,
        "stats": {"speed": 100, "acceleration": 99, "handling": 92, "braking": 92, "durability": 45},
        "color": (0.6, 0.1, 0.8),  # Purple
        "mesh_size": (1.85, 0.8, 3.8),
        "collision_size": (2.05, 1.0, 4.1),
        "wheel_positions": {
            "FR": (1.02, 0.4, 1.6),
            "FL": (-1.02, 0.4, 1.6),
            "RR": (1.02, 0.4, -1.6),
            "RL": (-1.02, 0.4, -1.6),
        }
    },
    "schafter_v12": {
        "id": "schafter_v12",
        "name": "Schafter V12",
        "class": "LUXURY",
        "price": 85000,
        "stats": {"speed": 80, "acceleration": 75, "handling": 70, "braking": 75, "durability": 80},
        "color": (0.1, 0.1, 0.1),  # Black
        "mesh_size": (2.1, 1.3, 4.8),
        "collision_size": (2.3, 1.5, 5.1),
        "wheel_positions": {
            "FR": (1.15, 0.6, 2.0),
            "FL": (-1.15, 0.6, 2.0),
            "RR": (1.15, 0.6, -2.0),
            "RL": (-1.15, 0.6, -2.0),
        }
    },
    "cognoscenti": {
        "id": "cognoscenti",
        "name": "Cognoscenti",
        "class": "LUXURY",
        "price": 150000,
        "stats": {"speed": 75, "acceleration": 70, "handling": 65, "braking": 70, "durability": 85},
        "color": (0.2, 0.2, 0.3),  # Dark blue
        "mesh_size": (2.15, 1.35, 5.0),
        "collision_size": (2.35, 1.55, 5.3),
        "wheel_positions": {
            "FR": (1.17, 0.62, 2.1),
            "FL": (-1.17, 0.62, 2.1),
            "RR": (1.17, 0.62, -2.1),
            "RL": (-1.17, 0.62, -2.1),
        }
    },
    "baller_le": {
        "id": "baller_le",
        "name": "Baller LE",
        "class": "LUXURY",
        "price": 180000,
        "stats": {"speed": 78, "acceleration": 72, "handling": 68, "braking": 72, "durability": 90},
        "color": (0.4, 0.3, 0.2),  # Brown
        "mesh_size": (2.2, 1.6, 4.7),
        "collision_size": (2.4, 1.8, 5.0),
        "wheel_positions": {
            "FR": (1.2, 0.7, 2.0),
            "FL": (-1.2, 0.7, 2.0),
            "RR": (1.2, 0.7, -2.0),
            "RL": (-1.2, 0.7, -2.0),
        }
    },
    "tailgater": {
        "id": "tailgater",
        "name": "Tailgater",
        "class": "FAMILY",
        "price": 35000,
        "stats": {"speed": 65, "acceleration": 60, "handling": 60, "braking": 65, "durability": 75},
        "color": (0.6, 0.6, 0.6),  # Silver
        "mesh_size": (2.0, 1.4, 4.6),
        "collision_size": (2.2, 1.6, 4.9),
        "wheel_positions": {
            "FR": (1.1, 0.6, 1.95),
            "FL": (-1.1, 0.6, 1.95),
            "RR": (1.1, 0.6, -1.95),
            "RL": (-1.1, 0.6, -1.95),
        }
    },
    "premier": {
        "id": "premier",
        "name": "Premier",
        "class": "FAMILY",
        "price": 25000,
        "stats": {"speed": 60, "acceleration": 55, "handling": 58, "braking": 60, "durability": 70},
        "color": (0.7, 0.7, 0.7),  # Light gray
        "mesh_size": (1.95, 1.35, 4.5),
        "collision_size": (2.15, 1.55, 4.8),
        "wheel_positions": {
            "FR": (1.07, 0.58, 1.9),
            "FL": (-1.07, 0.58, 1.9),
            "RR": (1.07, 0.58, -1.9),
            "RL": (-1.07, 0.58, -1.9),
        }
    },
    "police_cruiser": {
        "id": "police_cruiser",
        "name": "Police Cruiser",
        "class": "POLICE",
        "price": 0,
        "stats": {"speed": 85, "acceleration": 80, "handling": 75, "braking": 80, "durability": 85},
        "color": (0.1, 0.1, 0.5),  # Police blue
        "mesh_size": (2.05, 1.4, 4.7),
        "collision_size": (2.25, 1.6, 5.0),
        "wheel_positions": {
            "FR": (1.12, 0.6, 2.0),
            "FL": (-1.12, 0.6, 2.0),
            "RR": (1.12, 0.6, -2.0),
            "RL": (-1.12, 0.6, -2.0),
        }
    },
    "police_interceptor": {
        "id": "police_interceptor",
        "name": "Police Interceptor",
        "class": "POLICE",
        "price": 0,
        "stats": {"speed": 95, "acceleration": 90, "handling": 85, "braking": 85, "durability": 80},
        "color": (0.0, 0.0, 0.4),  # Dark police blue
        "mesh_size": (2.0, 1.3, 4.6),
        "collision_size": (2.2, 1.5, 4.9),
        "wheel_positions": {
            "FR": (1.1, 0.58, 1.95),
            "FL": (-1.1, 0.58, 1.95),
            "RR": (1.1, 0.58, -1.95),
            "RL": (-1.1, 0.58, -1.95),
        }
    },
    "police_helicopter": {
        "id": "police_helicopter",
        "name": "Police Helicopter",
        "class": "POLICE",
        "price": 0,
        "stats": {"speed": 120, "acceleration": 60, "handling": 50, "braking": 40, "durability": 60},
        "color": (0.0, 0.0, 0.6),  # Police blue
        "mesh_size": (2.5, 1.0, 6.0),
        "collision_size": (2.7, 1.2, 6.5),
        "wheel_positions": {
            "FR": (1.35, 0.3, 2.5),
            "FL": (-1.35, 0.3, 2.5),
            "RR": (1.35, 0.3, -2.5),
            "RL": (-1.35, 0.3, -2.5),
        }
    },
    "hauler": {
        "id": "hauler",
        "name": "Hauler",
        "class": "TRUCK",
        "price": 65000,
        "stats": {"speed": 55, "acceleration": 40, "handling": 45, "braking": 50, "durability": 100},
        "color": (0.5, 0.4, 0.3),  # Tan
        "mesh_size": (2.5, 2.5, 8.0),
        "collision_size": (2.7, 2.7, 8.5),
        "wheel_positions": {
            "FR": (1.35, 1.0, 3.0),
            "FL": (-1.35, 1.0, 3.0),
            "RR": (1.35, 1.0, -3.0),
            "RL": (-1.35, 1.0, -3.0),
        }
    },
    "phantom": {
        "id": "phantom",
        "name": "Phantom",
        "class": "TRUCK",
        "price": 80000,
        "stats": {"speed": 50, "acceleration": 35, "handling": 40, "braking": 45, "durability": 100},
        "color": (0.3, 0.3, 0.3),  # Dark gray
        "mesh_size": (2.6, 2.8, 9.0),
        "collision_size": (2.8, 3.0, 9.5),
        "wheel_positions": {
            "FR": (1.4, 1.1, 3.5),
            "FL": (-1.4, 1.1, 3.5),
            "RR": (1.4, 1.1, -3.5),
            "RL": (-1.4, 1.1, -3.5),
        }
    },
    "akuma": {
        "id": "akuma",
        "name": "Akuma",
        "class": "MOTORCYCLE",
        "price": 45000,
        "stats": {"speed": 95, "acceleration": 98, "handling": 90, "braking": 85, "durability": 30},
        "color": (0.9, 0.0, 0.0),  # Red
        "mesh_size": (0.8, 1.1, 2.2),
        "collision_size": (0.9, 1.2, 2.4),
        "wheel_positions": {
            "FR": (0.4, 0.4, 1.0),
            "FL": (-0.4, 0.4, 1.0),
            "RR": (0.4, 0.4, -1.0),
            "RL": (-0.4, 0.4, -1.0),
        }
    },
    "bati_801": {
        "id": "bati_801",
        "name": "Bati 801",
        "class": "MOTORCYCLE",
        "price": 55000,
        "stats": {"speed": 97, "acceleration": 95, "handling": 92, "braking": 88, "durability": 35},
        "color": (0.0, 0.0, 0.0),  # Black
        "mesh_size": (0.75, 1.05, 2.1),
        "collision_size": (0.85, 1.15, 2.3),
        "wheel_positions": {
            "FR": (0.38, 0.38, 0.95),
            "FL": (-0.38, 0.38, 0.95),
            "RR": (0.38, 0.38, -0.95),
            "RL": (-0.38, 0.38, -0.95),
        }
    },
    "sanchez": {
        "id": "sanchez",
        "name": "Sanchez",
        "class": "OFFROAD",
        "price": 15000,
        "stats": {"speed": 75, "acceleration": 70, "handling": 85, "braking": 70, "durability": 50},
        "color": (0.0, 0.6, 0.0),  # Green
        "mesh_size": (0.85, 1.15, 2.3),
        "collision_size": (0.95, 1.25, 2.5),
        "wheel_positions": {
            "FR": (0.42, 0.5, 1.05),
            "FL": (-0.42, 0.5, 1.05),
            "RR": (0.42, 0.5, -1.05),
            "RL": (-0.42, 0.5, -1.05),
        }
    },
    "rebel": {
        "id": "rebel",
        "name": "Rebel",
        "class": "OFFROAD",
        "price": 40000,
        "stats": {"speed": 70, "acceleration": 65, "handling": 75, "braking": 65, "durability": 90},
        "color": (0.4, 0.5, 0.3),  # Olive
        "mesh_size": (2.2, 1.8, 4.8),
        "collision_size": (2.4, 2.0, 5.1),
        "wheel_positions": {
            "FR": (1.2, 0.8, 2.0),
            "FL": (-1.2, 0.8, 2.0),
            "RR": (1.2, 0.8, -2.0),
            "RL": (-1.2, 0.8, -2.0),
        }
    },
    "bus": {
        "id": "bus",
        "name": "Bus",
        "class": "COMMERCIAL",
        "price": 0,
        "stats": {"speed": 50, "acceleration": 30, "handling": 40, "braking": 45, "durability": 95},
        "color": (0.8, 0.8, 0.0),  # Yellow
        "mesh_size": (2.5, 2.8, 10.0),
        "collision_size": (2.7, 3.0, 10.5),
        "wheel_positions": {
            "FR": (1.35, 1.2, 4.0),
            "FL": (-1.35, 1.2, 4.0),
            "RR": (1.35, 1.2, -4.0),
            "RL": (-1.35, 1.2, -4.0),
        }
    },
    "taxi": {
        "id": "taxi",
        "name": "Taxi",
        "class": "COMMERCIAL",
        "price": 0,
        "stats": {"speed": 70, "acceleration": 65, "handling": 65, "braking": 70, "durability": 75},
        "color": (1.0, 0.9, 0.0),  # Yellow
        "mesh_size": (2.0, 1.4, 4.6),
        "collision_size": (2.2, 1.6, 4.9),
        "wheel_positions": {
            "FR": (1.1, 0.6, 1.95),
            "FL": (-1.1, 0.6, 1.95),
            "RR": (1.1, 0.6, -1.95),
            "RL": (-1.1, 0.6, -1.95),
        }
    },
    "ambulance": {
        "id": "ambulance",
        "name": "Ambulance",
        "class": "EMERGENCY",
        "price": 0,
        "stats": {"speed": 80, "acceleration": 75, "handling": 70, "braking": 75, "durability": 85},
        "color": (1.0, 1.0, 1.0),  # White
        "mesh_size": (2.2, 2.0, 5.5),
        "collision_size": (2.4, 2.2, 5.8),
        "wheel_positions": {
            "FR": (1.2, 0.9, 2.3),
            "FL": (-1.2, 0.9, 2.3),
            "RR": (1.2, 0.9, -2.3),
            "RL": (-1.2, 0.9, -2.3),
        }
    },
    "firetruck": {
        "id": "firetruck",
        "name": "Fire Truck",
        "class": "EMERGENCY",
        "price": 0,
        "stats": {"speed": 55, "acceleration": 40, "handling": 45, "braking": 50, "durability": 95},
        "color": (0.9, 0.0, 0.0),  # Red
        "mesh_size": (2.5, 2.5, 8.0),
        "collision_size": (2.7, 2.7, 8.5),
        "wheel_positions": {
            "FR": (1.35, 1.0, 3.0),
            "FL": (-1.35, 1.0, 3.0),
            "RR": (1.35, 1.0, -3.0),
            "RL": (-1.35, 1.0, -3.0),
        }
    },
}


def generate_scene(vehicle_def: dict) -> str:
    """Generate a .tscn file content for a vehicle."""
    v = vehicle_def
    vid = v["id"]

    # Color as Godot Color
    r, g, b = v["color"]
    color_str = f"Color({r}, {g}, {b}, 1)"

    # Mesh size
    mx, my, mz = v["mesh_size"]
    mesh_size_str = f"Vector3({mx}, {my}, {mz})"

    # Collision size
    cx, cy, cz = v["collision_size"]
    collision_size_str = f"Vector3({cx}, {cy}, {cz})"

    # Collision position (center of collision box)
    collision_pos_y = cy / 2.0
    collision_pos_str = f"Vector3(0, {collision_pos_y}, 0)"

    # Mesh position (center of mesh)
    mesh_pos_y = my / 2.0 + 0.1  # Slightly above collision
    mesh_pos_str = f"Vector3(0, {mesh_pos_y}, 0)"

    # Wheel positions
    wp = v["wheel_positions"]

    scene = f"""[gd_scene load_steps=3 format=3 uid://{vid[:8]}]

[ext_resource type="Script" path="res://scripts/vehicles/vehicle_base.gd" id="1"]

[node name="{vid}" type="VehicleBody3D"]
script = ExtResource("1")
vehicle_id = "{vid}"
vehicle_name = "{v["name"]}"
vehicle_class = {v["class"]}
price = {v["price"]}
stats = {v["stats"]}

[node name="{vid}/CollisionShape" type="CollisionShape3D" parent="."]
shape = BoxShape3D.new()
shape.size = {collision_size_str}
position = {collision_pos_str}

[node name="{vid}/MeshInstance" type="MeshInstance3D" parent="."]
mesh = BoxMesh.new()
mesh.size = {mesh_size_str}
position = {mesh_pos_str}
material_override = StandardMaterial3D.new()
material_override.albedo_color = {color_str}

[node name="{vid}/WheelFR" type="VehicleWheel3D" parent="."]
position = Vector3({wp["FR"][0]}, {wp["FR"][1]}, {wp["FR"][2]})
suspension_travel = 0.3
suspension_stiffness = 25.0
suspension_max_force = 5000.0
friction_slip = 1.5
roll_influence = 0.5
use_as_traction = true
use_as_steering = true

[node name="{vid}/WheelFL" type="VehicleWheel3D" parent="."]
position = Vector3({wp["FL"][0]}, {wp["FL"][1]}, {wp["FL"][2]})
suspension_travel = 0.3
suspension_stiffness = 25.0
suspension_max_force = 5000.0
friction_slip = 1.5
roll_influence = 0.5
use_as_traction = true
use_as_steering = true

[node name="{vid}/WheelRR" type="VehicleWheel3D" parent="."]
position = Vector3({wp["RR"][0]}, {wp["RR"][1]}, {wp["RR"][2]})
suspension_travel = 0.3
suspension_stiffness = 25.0
suspension_max_force = 5000.0
friction_slip = 1.5
roll_influence = 0.5
use_as_traction = true
use_as_steering = false

[node name="{vid}/WheelRL" type="VehicleWheel3D" parent="."]
position = Vector3({wp["RL"][0]}, {wp["RL"][1]}, {wp["RL"][2]})
suspension_travel = 0.3
suspension_stiffness = 25.0
suspension_max_force = 5000.0
friction_slip = 1.5
roll_influence = 0.5
use_as_traction = true
use_as_steering = false
"""
    return scene


def main():
    output_dir = "/home/kali/CityLife/scenes/vehicles"
    os.makedirs(output_dir, exist_ok=True)

    for vid, vdef in VEHICLE_DEFINITIONS.items():
        scene_content = generate_scene(vdef)
        filepath = os.path.join(output_dir, f"{vid}.tscn")
        with open(filepath, "w") as f:
            f.write(scene_content)
        print(f"Generated: {filepath}")

    print(f"\nGenerated {len(VEHICLE_DEFINITIONS)} vehicle scenes!")


if __name__ == "__main__":
    main()