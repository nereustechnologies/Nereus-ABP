import math


def angle_between_points_180(A, B, C):
    """
    Original logic: returns angle in range 0 to 180
    """
    AB = [A[0] - B[0], A[1] - B[1]]
    CB = [C[0] - B[0], C[1] - B[1]]

    dot_val = AB[0] * CB[0] + AB[1] * CB[1]

    mag_ab = math.sqrt(AB[0] ** 2 + AB[1] ** 2)
    mag_cb = math.sqrt(CB[0] ** 2 + CB[1] ** 2)

    if mag_ab == 0 or mag_cb == 0:
        return 0.0

    cos_angle = dot_val / (mag_ab * mag_cb)

    # Clamp for numerical safety
    cos_angle = max(-1.0, min(1.0, cos_angle))

    angle_deg = math.degrees(math.acos(cos_angle))
    return angle_deg


def angle_between_points_signed(A, B, C):
    """
    Signed logic: returns angle in range -180 to 180
    """
    AB = [A[0] - B[0], A[1] - B[1]]
    CB = [C[0] - B[0], C[1] - B[1]]

    dot_val = AB[0] * CB[0] + AB[1] * CB[1]
    cross_val = AB[0] * CB[1] - AB[1] * CB[0]

    angle_deg = math.degrees(math.atan2(cross_val, dot_val))
    return angle_deg


def angle_between_points_360(A, B, C):
    """
    Full rotation logic: returns angle in range 0 to 360
    """
    AB = [A[0] - B[0], A[1] - B[1]]
    CB = [C[0] - B[0], C[1] - B[1]]

    dot_val = AB[0] * CB[0] + AB[1] * CB[1]
    cross_val = AB[0] * CB[1] - AB[1] * CB[0]

    angle_deg = math.degrees(math.atan2(cross_val, dot_val))

    if angle_deg < 0:
        angle_deg += 360

    return angle_deg


def main():
    # Angles to test
    angles = [0, 45, 90, 135, 180, 225, 270, 315, 360]

    # Each row = [Ax, Ay, Bx, By, Cx, Cy]
    test_points = []

    # Vertex point
    B = [0.0, 0.0]

    # Reference direction BA
    A = [1.0, 0.0]

    # Generate test points
    for theta in angles:
        C = [math.cos(math.radians(theta)), math.sin(math.radians(theta))]
        test_points.append([A[0], A[1], B[0], B[1], C[0], C[1]])

    print("Test points array:")
    print("[Ax, Ay, Bx, By, Cx, Cy]")
    for row in test_points:
        print([round(v, 6) for v in row])

    print("\nAngle comparison")
    print("-----------------------------------------------------------------")
    print(f"{'Target':>8} | {'0-180 (acos)':>14} | {'-180 to 180':>13} | {'0 to 360':>10}")
    print("-----------------------------------------------------------------")

    for i, row in enumerate(test_points):
        A = row[0:2]
        B = row[2:4]
        C = row[4:6]

        angle_180 = angle_between_points_180(A, B, C)
        angle_signed = angle_between_points_signed(A, B, C)
        angle_360 = angle_between_points_360(A, B, C)

        print(f"{angles[i]:8.0f} | {angle_180:14.2f} | {angle_signed:13.2f} | {angle_360:10.2f}")


if __name__ == "__main__":
    main()