#!/usr/bin/python3

import math
import argparse


def calculate_fov(fov, horizontal, vertical, viewzoom):
    viewzoom_multiplier = 1 / viewzoom
    frustumy = math.tan(fov * math.pi / 360) * 0.75 * viewzoom_multiplier
    frustumx = frustumy * horizontal / vertical

    fovx = math.atan2(frustumx, 1) / math.pi * 360
    fovy = math.atan2(frustumy, 1) / math.pi * 360

    print(fov, "degrees of hfov with 4:3 resolution (unstretched without black bars) actually gives:")
    print("Horizontal FOV =", fovx)
    print("Vertical   FOV =", fovy)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Process in-game fov cvars to horizontal and vertical degrees.')
    parser.add_argument('fov', type=float,
                        help="in-game fov cvar, degrees of hfov with 4:3 resolution, required field")
    parser.add_argument('horizontalAspectRatio', type=float, default=16, nargs='?',
                        help="Horizontal num of the aspect ratio, for 16:9 that is 16, default: 16")
    parser.add_argument('verticalAspectRatio', type=float, default=9, nargs='?',
                        help="Vertical num of the aspect ratio, for 16:9 that is 9, default: 9")
    parser.add_argument('viewzoom', type=float, default=1, nargs='?',
                        help="Zoom amount, default: 1 / no zoom")
    args = parser.parse_args()

    if (args.fov < 1 or args.fov > 170):
        print("WARNING: Xonotic's fov is currently restricted between 1 and 170, calculations might be broken with this number.")
    if (args.viewzoom < 1 or args.viewzoom > 30):
        print("WARNING: Xonotic's zoom is currently restricted between 1 and 30, calculations might be broken with this number.")

    calculate_fov(args.fov, args.horizontalAspectRatio, args.verticalAspectRatio, args.viewzoom)

